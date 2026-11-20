<#
.SYNOPSIS
    Recreates a Task Snapshot as a PowerShell initial session state.

.DESCRIPTION
    Creates independent data, function, alias, and module state for one task
    without importing arbitrary state from the caller.

.PARAMETER Snapshot
    The Task Snapshot to recreate.

.EXAMPLE
    $State = New-PleaseWorkInitialSessionState -Snapshot $Snapshot

    Returns initial session state for one disposable task runspace.

.NOTES
    Examples run in the PleaseWork module's scope.
#>
function New-PleaseWorkInitialSessionState {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Runspaces.InitialSessionState])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [pscustomobject] $Snapshot
    )

    $InitialSessionState =
        [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()

    foreach ($Variable in $Snapshot.Variables) {
        $Value = Copy-PleaseWorkSnapshotValue `
            -InputObject $Variable.Value `
            -Name $Variable.Name
        $InitialSessionState.Variables.Add(
            [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new(
                $Variable.Name,
                $Value,
                "TaskFile variable '$($Variable.Name)'."
            )
        )
    }

    foreach ($Function in $Snapshot.Functions) {
        $InitialSessionState.Commands.Add(
            [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new(
                $Function.Name,
                $Function.Definition,
                $Function.Options,
                $null
            )
        )
    }

    foreach ($Alias in $Snapshot.Aliases) {
        $InitialSessionState.Commands.Add(
            [System.Management.Automation.Runspaces.SessionStateAliasEntry]::new(
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
