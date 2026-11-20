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

        [Parameter(Position=1,ParameterSetName='Run')]
        [ArgumentCompleter({ Complete-PleaseWorkTask @args })]
        [string] $HelpTaskName,

        [Parameter(Mandatory,ParameterSetName='List')]
        [switch] $List,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $TaskFile,

        [Parameter(ParameterSetName='Run')]
        [switch] $PassThru
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
                if ($env:PLEASE_DEFAULT_TASK) {
                    $env:PLEASE_DEFAULT_TASK
                } else {
                    $TaskDeclarations[0].Name
                }
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

        $TaskDeclarations = @(Get-TaskFileDeclaration -Path $TaskFilePath)
        $UseNativeHelp = $Name -ieq 'help' -and
            -not @($TaskDeclarations | Where-Object Name -ieq 'help')
        if ($List -or $UseNativeHelp) {
            $DefaultTaskName = if ($env:PLEASE_DEFAULT_TASK) {
                $env:PLEASE_DEFAULT_TASK
            } else {
                $TaskDeclarations[0].Name
            }
            $TaskList = foreach ($Declaration in $TaskDeclarations) {
                $Description = $Declaration.Description
                if (-not [string]::IsNullOrWhiteSpace($Description)) {
                    $Description = $Description.Trim()
                }

                [pscustomobject] @{
                    Name = $Declaration.Name
                    Dependencies = [string[]] $Declaration.Dependencies
                    PathSpecs = [string[]] $Declaration.PathSpecs
                    Default = $Declaration.Name -eq $DefaultTaskName
                    Description = $Description
                }
            }
        }

        if ($List) { return $TaskList }

        if ($UseNativeHelp -and -not [string]::IsNullOrWhiteSpace($HelpTaskName)) {
            $HelpDeclaration = $TaskDeclarations |
                Where-Object Name -ieq $HelpTaskName |
                Select-Object -First 1
            if ($null -eq $HelpDeclaration) {
                throw "Task '$HelpTaskName' is not defined."
            }
            return $HelpDeclaration.Help
        }

        if ($UseNativeHelp) {
            $TaskList | Format-PleaseWorkTaskHelp
            return
        }

        $TaskSnapshot = New-PleaseWorkTaskSnapshot -Path $TaskFilePath
        $TaskSet = New-PleaseWorkSnapshotTaskSet -Snapshot $TaskSnapshot

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
        $TaskContext = New-PleaseWorkTaskContext `
            -TaskFilePath $TaskFilePath `
            -TaskFileRoot $TaskFileRoot `
            -TaskOrder $TaskOrder `
            -Tasks $TaskSet.Tasks `
            -Config $TaskSet.Config
        $Changeset = $TaskContext.Changeset
        $ExecutedTasks = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $OriginalLocation = Get-Location
        $OriginalPleaseWorkConfig = $script:PleaseWorkConfig
        try {
            # Expose this TaskFile's config to module helpers, then restore prior module state.
            $script:PleaseWorkConfig = $TaskSet.Config
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
                        -Arguments $(if ($TaskName -ieq $Name) { $TaskArguments } else { $null }) `
                        -Context $CurrentTaskContext `
                        -WorkingDirectory $TaskFileRoot `
                        -Snapshot $TaskSet.Snapshot `
                        -StreamCaller $PSCmdlet `
                        -Result ([ref] $TaskResult) |
                        ForEach-Object { $TaskOutput.Add($_) }
                } catch {
                    $TaskResult | Add-Member `
                        -NotePropertyName Output `
                        -NotePropertyValue $TaskOutput.ToArray() `
                        -Force

                    if ($PassThru) {
                        $TaskResult
                    } else {
                        $TaskOutput
                    }
                    throw
                }

                $TaskResult | Add-Member `
                    -NotePropertyName Output `
                    -NotePropertyValue $TaskOutput.ToArray() `
                    -Force

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
            $script:PleaseWorkConfig = $OriginalPleaseWorkConfig
            Set-Location -LiteralPath $OriginalLocation.Path
        }
    }
}
