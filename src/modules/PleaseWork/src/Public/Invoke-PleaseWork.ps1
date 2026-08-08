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
        [ArgumentCompleter({
            param (
                [string] $CommandName,
                [string] $ParameterName,
                [string] $WordToComplete,
                [System.Management.Automation.Language.CommandAst] $CommandAst,
                [System.Collections.IDictionary] $FakeBoundParameters
            )

            try {
                $TaskFilePath = Resolve-TaskFilePath -Path $FakeBoundParameters['TaskFile']
                foreach ($Declaration in (Get-TaskFileDeclaration -Path $TaskFilePath)) {
                    if ($Declaration.Name.StartsWith($WordToComplete, [StringComparison]::OrdinalIgnoreCase)) {
                        [System.Management.Automation.CompletionResult]::new(
                            $Declaration.Name,
                            $Declaration.Name,
                            [System.Management.Automation.CompletionResultType]::ParameterValue,
                            $Declaration.Name
                        )
                    }
                }
                if ('help'.StartsWith($WordToComplete, [StringComparison]::OrdinalIgnoreCase)) {
                    [System.Management.Automation.CompletionResult]::new(
                        'help',
                        'help',
                        [System.Management.Automation.CompletionResultType]::ParameterValue,
                        'Display help information'
                    )
                }
            } catch {
                return @()
            }
        })]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName='List')]
        [switch] $List,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $TaskFile,

        [Parameter(ParameterSetName='Run')]
        [switch] $PassThru,

        [Parameter(ParameterSetName='Run',ValueFromRemainingArguments)]
        [object[]] $RemainingArguments
    )

    $TaskFilePath = Resolve-TaskFilePath -Path $TaskFile
    $TaskFileRoot = Split-Path -Parent $TaskFilePath
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
                Invoke-PleaseWorkTask `
                    -Name $TaskName `
                    -ScriptBlock $Task.ScriptBlock `
                    -Arguments $RemainingArguments `
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
