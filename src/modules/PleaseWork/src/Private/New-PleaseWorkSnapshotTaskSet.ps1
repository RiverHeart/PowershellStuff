using namespace System.Collections.Generic

<#
.SYNOPSIS
    Converts a Task Snapshot into a task set for the PleaseWork planner.

.DESCRIPTION
    Recreates unbound task scriptblocks from their source text while retaining the
    Task Snapshot for isolated task execution.

.PARAMETER Snapshot
    The Task Snapshot to prepare.

.EXAMPLE
    New-PleaseWorkSnapshotTaskSet -Snapshot $Snapshot

    Returns a task set accepted by the PleaseWork planner.

.NOTES
    Examples run in the PleaseWork module's scope.
#>
function New-PleaseWorkSnapshotTaskSet {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [pscustomobject] $Snapshot
    )

    $Tasks = [List[hashtable]]::new()
    foreach ($Task in $Snapshot.Tasks) {
        $Tasks.Add(@{
            Name = $Task.Name
            Description = $Task.Description
            Help = $Task.Help
            Dependencies = $Task.Dependencies
            PathSpecs = $Task.PathSpecs
            ScriptBlock = [scriptblock]::Create($Task.ScriptBlockText)
        })
    }

    Write-Output (
        New-PleaseWorkPreparedTaskSet `
            -Tasks $Tasks `
            -Config $Snapshot.Config `
            -Snapshot $Snapshot
    ) -NoEnumerate
}
