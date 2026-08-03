using namespace System.Collections.Generic

<#
.SYNOPSIS
    Resolves a task and its dependencies in execution order.
#>
function Resolve-TaskOrder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [Dictionary[string, hashtable]] $Tasks
    )

    $Dag = [DirectedAcyclicGraph]::new()

    $AddTask = {
        param ([string] $TaskName)

        if (-not $Tasks.ContainsKey($TaskName)) {
            throw "Task '$TaskName' is not defined."
        }

        if ($Dag.ContainsNode($TaskName)) {
            return
        }

        $Dag.AddNode($TaskName)
        foreach ($Dependency in $Tasks[$TaskName].Dependencies) {
            & $AddTask $Dependency
            try {
                $Dag.AddEdge($Dependency, $TaskName)
            } catch [System.InvalidOperationException] {
                throw "Task dependency cycle detected for '$Name'."
            }
        }
    }

    & $AddTask $Name
    return $Dag.GetTopologicalOrder()
}
