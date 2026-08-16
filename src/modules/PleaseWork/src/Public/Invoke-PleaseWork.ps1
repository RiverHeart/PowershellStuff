using namespace System.Collections.Generic

<#
.SYNOPSIS
    Runs a task and its dependencies from a TaskFile.

.EXAMPLE
    please build

.EXAMPLE
    Invoke-PleaseWork -TaskFile ./tasks.ps1 -Name test
#>
function Invoke-PleaseWork {
    [CmdletBinding(DefaultParameterSetName='Run',SupportsShouldProcess,ConfirmImpact='Low')]
    [Alias('pw', 'please')]
    param(
        [Parameter(Position=0,ParameterSetName='Run')]
        [ArgumentCompleter({ Complete-PleaseWorkTask @args })]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName='List')]
        [switch] $List,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $TaskFile,

        [Parameter(ParameterSetName='Run')]
        [switch] $PassThru,

        [Parameter()]
        [switch] $Runspace
    )

    dynamicparam {
        # Build task parameters from declaration ASTs so PowerShell can bind them normally without
        # executing TaskFile setup code while it is still discovering this command's parameters.
        $TaskParameters = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
        if (-not $PSBoundParameters.ContainsKey('List')) {
            # Unbound parameter variables can fall through to an outer scope during dynamicparam.
            # PSBoundParameters contains only the static values supplied for this invocation.
            $BoundTaskFile = if ($PSBoundParameters.ContainsKey('TaskFile')) {
                $PSBoundParameters['TaskFile']
            } else {
                $null
            }
            $BoundTaskName = if ($PSBoundParameters.ContainsKey('Name')) {
                $PSBoundParameters['Name']
            } else {
                $null
            }
            $TaskFilePath = Resolve-TaskFilePath -Path $BoundTaskFile
            $TaskDeclarations = @(Get-TaskFileDeclaration -Path $TaskFilePath)
            $SelectedTaskName = if ([string]::IsNullOrEmpty($BoundTaskName)) {
                $TaskDeclarations[0].Name
            } else {
                $BoundTaskName
            }
            $TaskDeclaration = $TaskDeclarations |
                Where-Object { $_.Name -ieq $SelectedTaskName } |
                Select-Object -First 1
            if ($null -ne $TaskDeclaration -and $TaskDeclaration.ParameterAsts.Count -gt 0) {
                $TaskParameters = Resolve-ParamBlock `
                    -ParameterAsts $TaskDeclaration.ParameterAsts `
                    -DefaultParameterSetName Run
            }
        }
        return $TaskParameters
    }

    end {
        $TaskFilePath = Resolve-TaskFilePath -Path $TaskFile
        $TaskFileRoot = Split-Path -Parent $TaskFilePath

        # PSBoundParameters also contains PleaseWork and common parameters; forward only parameters
        # generated from the selected task's declaration.
        $TaskArguments = @{}
        foreach ($ParameterName in $TaskParameters.Keys) {
            if ($PSBoundParameters.ContainsKey($ParameterName)) {
                $TaskArguments[$ParameterName] = $PSBoundParameters[$ParameterName]
            }
        }

        if ($Runspace) {
            $InvocationParameters = @{}
            foreach ($ParameterName in $PSBoundParameters.Keys) {
                if ($ParameterName -ne 'Runspace') {
                    $InvocationParameters[$ParameterName] = $PSBoundParameters[$ParameterName]
                }
            }
            $InvocationParameters.TaskFile = $TaskFilePath

            Invoke-PleaseWorkInRunspace `
                -ModulePath $MyInvocation.MyCommand.Module.Path `
                -InvocationParameters $InvocationParameters `
                -WorkingDirectory $PWD.ProviderPath
            return
        }

        $TaskSet = Read-TaskFile -Path $TaskFilePath

        # Support a native 'help' task that displays the available tasks and their descriptions.
        $UseNativeHelp = $Name -ieq 'help' -and -not $TaskSet.Tasks.ContainsKey('help')

        # If the user requested a task list or help, build a list of tasks and their descriptions.
        if ($List -or $UseNativeHelp) {
            $TaskList = foreach ($TaskName in $TaskSet.TaskNames) {
                $Description = $TaskSet.Tasks[$TaskName].Help.Description
                if (-not [string]::IsNullOrWhiteSpace($Description)) {
                    $Description = $Description.Trim()
                }

                [pscustomobject] @{
                    Name = $TaskName
                    Dependencies = [string[]] $TaskSet.Tasks[$TaskName].Dependencies
                    PathSpecs = [string[]] $TaskSet.Tasks[$TaskName].PathSpecs
                    Default = $TaskName -eq $TaskSet.DefaultTask
                    Description = $Description
                }
            }
        }

        if ($List) { return $TaskList }

        # If the user requested help, display the available tasks and their descriptions.
        # NOTE: Might wanna pull in Expand-Tab from GrabBag instead of doing this manually.
        if ($UseNativeHelp) {
            $NameWidth = ($TaskList.Name | Measure-Object -Property Length -Maximum).Maximum
            'Available tasks:'
            foreach ($TaskInfo in $TaskList) {
                $HelpLine = '  {0}' -f $TaskInfo.Name.PadRight($NameWidth)
                if (-not [string]::IsNullOrWhiteSpace($TaskInfo.Description)) {
                    $HelpLine += '  {0}' -f ($TaskInfo.Description -replace '\s+', ' ')
                }
                $HelpLine.TrimEnd()
            }
            return
        }

        if ([string]::IsNullOrEmpty($Name)) {
            $Name = $TaskSet.DefaultTask
        }

        $TaskOrder = Resolve-TaskOrder -Name $Name -Tasks $TaskSet.Tasks
        $TaskPlan = $TaskOrder -join ', '
        if (-not $PSCmdlet.ShouldProcess($Name, "Run task plan: $TaskPlan")) {
            return
        }

        # As much as I would like to populate PSScriptRoot in the context of the task scriptblock
        # Powershell doesn't allow it.
        $TaskContext = @{
            TaskFilePath = $TaskFilePath
            TaskFileRoot = $TaskFileRoot
        }
        $Changeset = $null
        if (@($TaskOrder | Where-Object { $TaskSet.Tasks[$_].PathSpecs.Count -gt 0 }).Count -gt 0) {
            $BaseRef = if ($TaskSet.Config.Contains('BaseRef')) {
                [string] $TaskSet.Config['BaseRef']
            } else {
                $null
            }
            if ([string]::IsNullOrWhiteSpace($BaseRef)) {
                throw "Tasks using changed() require a non-empty `$PleaseConfig.BaseRef."
            }
            $HeadRef = if ($TaskSet.Config.Contains('HeadRef')) {
                [string] $TaskSet.Config['HeadRef']
            } else {
                'HEAD'
            }
            $Changeset = Get-GitChangeset `
                -WorkingDirectory $TaskFileRoot `
                -BaseRef $BaseRef `
                -HeadRef $HeadRef
            $TaskContext.Changeset = $Changeset
            $TaskContext.GitRoot = $Changeset.Root
        } elseif (Get-Command 'git' -ErrorAction SilentlyContinue) {
            $GitRoot = git -C $TaskFileRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0) {
                $TaskContext.GitRoot = [string] @($GitRoot)[0]
            }
        }
        $ExecutedTasks = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $OriginalLocation = Get-Location
        try {
            foreach ($TaskName in $TaskOrder) {
                Set-Location -LiteralPath $TaskFileRoot
                $Task = $TaskSet.Tasks[$TaskName]
                [string[]] $ChangedFiles = @()
                if ($Task.PathSpecs.Count -gt 0) {
                    $DependencyRan = @($Task.Dependencies | Where-Object { $ExecutedTasks.Contains($_) }).Count -gt 0
                    $ChangedFiles = @(Get-GitChangedPath `
                        -Changeset $Changeset `
                        -PathSpec $Task.PathSpecs |
                        ForEach-Object {
                            [System.IO.Path]::GetFullPath((Join-Path $Changeset.Root $_))
                        })
                    if ($ChangedFiles.Count -eq 0 -and -not $DependencyRan) {
                        Write-Verbose "Skipped task '$TaskName' because its changeset filters did not match."
                        continue
                    }
                }

                $CurrentTaskContext = @{}
                foreach ($ContextName in $TaskContext.Keys) {
                    $CurrentTaskContext[$ContextName] = $TaskContext[$ContextName]
                }
                $CurrentTaskContext.ChangedFiles = $ChangedFiles
                $TaskResult = $null
                $TaskOutput = [List[object]]::new()
                try {
                    # Dependencies run without the requested task's arguments.
                    Invoke-PleaseWorkTask `
                        -Name $TaskName `
                        -ScriptBlock $Task.ScriptBlock `
                        -Arguments $(if ($TaskName -ieq $Name) { $TaskArguments } else { $null }) `
                        -Context $CurrentTaskContext `
                        -Result ([ref] $TaskResult) |
                        ForEach-Object { $TaskOutput.Add($_) }
                } catch {
                    $TaskResult | Add-Member `
                        -NotePropertyName Output `
                        -NotePropertyValue $TaskOutput.ToArray()

                    if ($PassThru) {
                        $TaskResult
                    } else {
                        $TaskOutput
                    }
                    throw
                }

                $TaskResult | Add-Member `
                    -NotePropertyName Output `
                    -NotePropertyValue $TaskOutput.ToArray()

                Write-Verbose (
                    "Completed task '$TaskName' in $($TaskResult.Duration). " +
                    "Exit code: $($TaskResult.ExitCode)."
                )

                if ($PassThru) {
                    $TaskResult
                } else {
                    $TaskOutput
                }

                if (-not $TaskResult.Succeeded) {
                    throw "Task '$TaskName' failed with exit code $($TaskResult.ExitCode)."
                }
                $null = $ExecutedTasks.Add($TaskName)
            }
        } finally {
            Set-Location -LiteralPath $OriginalLocation.Path
        }
    }
}
