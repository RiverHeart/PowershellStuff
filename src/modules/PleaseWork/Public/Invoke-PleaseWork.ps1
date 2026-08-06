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
    if ($List) {
        foreach ($TaskName in $TaskSet.TaskNames) {
            $Description = $TaskSet.Tasks[$TaskName].Help.Description
            if (-not [string]::IsNullOrWhiteSpace($Description)) {
                $Description = $Description.Trim()
            }

            [pscustomobject] @{
                Name = $TaskName
                Dependencies = [string[]] $TaskSet.Tasks[$TaskName].Dependencies
                Default = $TaskName -eq $TaskSet.DefaultTask
                Description = $Description
            }
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
    if (Get-Command 'git' -ErrorAction SilentlyContinue) {
        $TaskContext.GitRoot = (git rev-parse --show-toplevel 2>$null)
    }
    $OriginalLocation = Get-Location
    try {
        foreach ($TaskName in $TaskOrder) {
            Set-Location -LiteralPath $TaskFileRoot
            $TaskResult = $null
            $TaskOutput = [List[object]]::new()
            try {
                Invoke-PleaseWorkTask `
                    -Name $TaskName `
                    -ScriptBlock $TaskSet.Tasks[$TaskName].ScriptBlock `
                    -Arguments $RemainingArguments `
                    -Context $TaskContext `
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
        }
    } finally {
        Set-Location -LiteralPath $OriginalLocation.Path
    }
}
