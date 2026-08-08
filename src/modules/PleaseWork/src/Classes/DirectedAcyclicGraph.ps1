using namespace System.Collections.Generic

class DirectedAcyclicGraph {
    hidden [List[string]] $Nodes
    hidden [hashtable] $Edges
    [bool] $EnableLogging

    DirectedAcyclicGraph() {
        $this.Nodes = [List[string]]::new()
        $this.Edges = @{}
        $this.EnableLogging = $false
    }

    [void] AddNode([string] $Node) {
        if ($this.Nodes -notcontains $Node) {
            $this.Nodes.Add($Node)
            $this.Edges[$Node] = @()
            $this.Log("Node '$Node' added.")
        }
    }

    [bool] ContainsNode([string] $Node) {
        return $this.Nodes -contains $Node
    }

    [string[]] GetOutgoingEdges([string] $Node) {
        if (-not $this.ContainsNode($Node)) {
            throw [System.ArgumentException]::new("Node '$Node' does not exist.")
        }

        return [string[]] $this.Edges[$Node]
    }

    [void] AddEdge([string] $From, [string] $To) {
        if ($this.Nodes -notcontains $From) {
            throw [System.ArgumentException]::new("Node '$From' does not exist.")
        }
        if ($this.Nodes -notcontains $To) {
            throw [System.ArgumentException]::new("Node '$To' does not exist.")
        }
        if ($this.Edges[$From] -contains $To) {
            return
        }
        if ($From -eq $To -or $this.IsReachable($To, $From)) {
            throw [System.InvalidOperationException]::new(
                "Adding edge from '$From' to '$To' would create a cycle."
            )
        }

        $this.Edges[$From] += $To
        $this.Log("Edge from '$From' to '$To' added.")
    }

    [void] RemoveNode([string] $Node) {
        if ($this.Nodes -contains $Node) {
            $this.Nodes.Remove($Node)
            $this.Edges.Remove($Node)
            [string[]] $Keys = $this.Edges.Keys
            foreach ($key in $Keys) {
                $this.Edges[$key] = $this.Edges[$key] | Where-Object { $_ -ne $Node }
            }
            $this.Log("Node '$Node' removed.")
        }
    }

    [void] RemoveEdge([string] $From, [string] $To) {
        if ($this.Nodes -contains $From -and $this.Nodes -contains $To) {
            $this.Edges[$From] = $this.Edges[$From] | Where-Object { $_ -ne $To }
            $this.Log("Edge from '$From' to '$To' removed.")
        }
    }

    hidden [bool] IsReachable([string] $From, [string] $To) {
        $Pending = [Stack[string]]::new()
        $Visited = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $Pending.Push($From)

        while ($Pending.Count -gt 0) {
            $Node = $Pending.Pop()
            if ($Node -eq $To) {
                return $true
            }
            if (-not $Visited.Add($Node)) {
                continue
            }

            foreach ($Neighbor in $this.Edges[$Node]) {
                $Pending.Push($Neighbor)
            }
        }

        return $false
    }

    <#
    .DESCRIPTION
        The `GetTopologicalOrder` method returns an array of node names representing a topological
        ordering of the nodes in the directed acyclic graph (DAG). A topological order is an
        ordering of the nodes such that for every directed edge from node A to node B, node A
        appears before node B in the ordering.

        This method uses Kahn's algorithm to compute the topological order. It first calculates
        the in-degree of each node (the number of incoming edges), then repeatedly selects nodes
        with in-degree 0, adds them to the order, and decreases the in-degree of their dependent
        nodes. If a cycle is detected (i.e., not all nodes can be added to the order), an
        exception is thrown.

        For example, consider a DAG representing task dependencies:
            dependency -> dependent
            lint       -> build
            test       -> build

        The initial in-degree would be:
            lint  = 0
            test  = 0
            build = 2

        The nodes with in-degree 0 (ready to be processed) would be:
            lint, test

        If we want parallel processing, we can safely assume that both `lint` and `test`
        can run concurrently before `build` because their in-degrees are 0, indicating that
        they have no unmet dependencies.

        After a dependency is processed successfully, the in-degree of the dependent nodes is
        decreased until it reaches 0, at which point the node is ready to be processed.
        This continues until all nodes are processed or a cycle is detected.

        For parallelism and failure handling, Kahn's algorithm should be exposed incrementally,
        allowing nodes with in-degree 0 to be processed as soon as they become available, rather than
        computing the entire topological order at once. This way, tasks can be executed in parallel
        as their dependencies are resolved, and failures can be handled dynamically without waiting
        for the complete topological sort to finish.

    .LINK
        https://en.wikipedia.org/wiki/Topological_sorting
    #>
    [string[]] GetTopologicalOrder() {
        $InDegree = @{}
        foreach ($Node in $this.Nodes) {
            $InDegree[$Node] = 0
        }

        foreach ($From in $this.Nodes) {
            foreach ($To in $this.Edges[$From]) {
                $InDegree[$To]++
            }
        }

        $Ready = [Queue[string]]::new()
        foreach ($Node in $this.Nodes) {
            if ($InDegree[$Node] -eq 0) {
                $Ready.Enqueue($Node)
            }
        }

        $Order = [List[string]]::new()

        while ($Ready.Count -gt 0) {
            $Node = $Ready.Dequeue()
            $Order.Add($Node)

            foreach ($Dependent in $this.Edges[$Node]) {
                $InDegree[$Dependent]--

                if ($InDegree[$Dependent] -eq 0) {
                    $Ready.Enqueue($Dependent)
                }
            }
        }

        if ($Order.Count -ne $this.Nodes.Count) {
            throw 'The graph contains a cycle.'
        }

        return $Order.ToArray()
    }

    [void] Log([string] $Message) {
        if ($this.EnableLogging) {
            Write-Host $Message
        }
    }
}