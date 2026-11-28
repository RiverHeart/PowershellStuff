using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces

<#
.SYNOPSIS
    Recreates a Task Snapshot as a PowerShell initial session state.

.DESCRIPTION
    Creates independent data, function, alias, and module state for one task
    without importing arbitrary state from the caller.

.PARAMETER Snapshot
    The Task Snapshot to recreate.

.PARAMETER SessionState
    The caller session state whose environment variables should be copied.

.EXAMPLE
    $State = New-PleaseWorkInitialSessionState -Snapshot $Snapshot

    Returns initial session state for one disposable task runspace.

.NOTES
    Examples run in the PleaseWork module's scope.
#>
function New-PleaseWorkInitialSessionState {
    [CmdletBinding()]
    [OutputType([InitialSessionState])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [pscustomobject] $Snapshot,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [SessionState] $SessionState
    )

    $InitialSessionState = [InitialSessionState]::CreateDefault2()

    $SessionState.InvokeProvider.ChildItem.Get('Env:', $false) |
        ForEach-Object {
            $EnvVar = $_
            $InitialSessionState.EnvironmentVariables.Add(
                [SessionStateVariableEntry]::new(
                    $EnvVar.Name,
                    $EnvVar.Value,
                    "TaskFile environment variable '$($EnvVar.Name)'."
                )
            )
        }

    foreach ($Variable in $Snapshot.Variables) {
        $Value = Copy-PleaseWorkSnapshotValue `
            -InputObject $Variable.Value `
            -Name $Variable.Name

        $InitialSessionState.Variables.Add(
            [SessionStateVariableEntry]::new(
                $Variable.Name,
                $Value,
                "TaskFile variable '$($Variable.Name)'."
            )
        )
    }

    foreach ($Function in $Snapshot.Functions) {
        $InitialSessionState.Commands.Add(
            [SessionStateFunctionEntry]::new(
                $Function.Name,
                $Function.Definition,
                $Function.Options,
                $null
            )
        )
    }

    foreach ($Alias in $Snapshot.Aliases) {
        $InitialSessionState.Commands.Add(
            [SessionStateAliasEntry]::new(
                $Alias.Name,
                $Alias.Definition,
                "TaskFile alias '$($Alias.Name)'.",
                $Alias.Options
            )
        )
    }

    [string[]] $ModulePaths = @(
        $Snapshot.RunnerModulePath
        $Snapshot.Modules.Path |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($ModulePaths.Count -gt 0) {
        $InitialSessionState.ImportPSModule($ModulePaths)
    }

    Write-Output -InputObject (, $InitialSessionState)
}
