using namespace System.Collections.Generic

# Directed Acyclic Graph
class DirectedAcyclicGraph {
    [List[string]] $Nodes
    [hashtable] $Edges
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

    [void] AddEdge([string] $From, [string] $To) {
        if ($this.Nodes -contains $From -and $this.Nodes -contains $To) {
            $this.Edges[$From] += $To
            $this.Log("Edge from '$From' to '$To' added.")
        }
    }

    [void] RemoveNode([string] $Node) {
        if ($this.Nodes -contains $Node) {
            $this.Nodes.Remove($Node)
            $this.Edges.Remove($Node)
            foreach ($key in $this.Edges.Keys) {
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

    <#
    .DESCRIPTION
        Checks if the directed acyclic graph contains any cycles.

        A cycle is a path in the graph that starts and ends at the same node, indicating
        a circular dependency.

        This method uses the DetectCycle helper method to perform a depth-first search
        and detect cycles in the graph.
    #>
    [bool] HasCycle() {
        $Visited = @{}
        $RecStack = @{}

        # Create dictionaries to keep track of visited nodes and the recursion stack
        # Visited is self explanatory but the recursion stack is used to keep track of
        # nodes currently in the recursion path during the depth-first search
        foreach ($Node in $this.Nodes) {
            $Visited[$Node] = $false
            $RecStack[$Node] = $false
        }

        # Perform a depth-first search from each unvisited node to detect cycles
        foreach ($Node in $this.Nodes) {
            if (-not $Visited[$Node]) {
                if ($this.DetectCycle($Node, $Visited, $RecStack)) {
                    return $true
                }
            }
        }
        return $false
    }

    <#
    .DESCRIPTION
        A cycle is a path in the graph that starts and ends at the same node, indicating
        a circular dependency.

        The DetectCycle method is a recursive helper function used by HasCycle to determine
        if there is a cycle starting from a specific node. It uses a recursion stack to keep
        track of the nodes currently in the recursion path, and if it encounters a node that
        is already in the recursion stack, a cycle is detected.
    #>
    [bool] DetectCycle([string] $Node, $Visited, $RecStack) {
        $Visited[$Node] = $true
        $RecStack[$Node] = $true

        foreach ($Neighbor in $this.Edges[$Node]) {
            if (-not $Visited[$Neighbor]) {
                if ($this.DetectCycle($Neighbor, $Visited, $RecStack)) {
                    return $true
                }
            } elseif ($RecStack[$Neighbor]) {
                return $true
            }
        }
        $RecStack[$Node] = $false
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

function Task {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromRemainingArguments)]
        [object[]] $Arguments
    )

    if ($Arguments.Length -eq 0) {
        throw "At least one argument (the scriptblock) is required."
    }

    $ScriptBlock = $Arguments[-1]
    if (-not ($ScriptBlock -is [scriptblock])) {
        throw [System.ArgumentException] "The last argument must be a scriptblock."
    }

    if ($Arguments.Length -gt 1) {
        [string[]] $Dependencies = $Arguments[0..($Arguments.Length - 2)]
    } else {
        [string[]] $Dependencies = @()
    }

    $Task = @{
        Name = $MyInvocation.MyCommand.Name.TrimEnd(':')
        Dependencies = $Dependencies
        ScriptBlock = $ScriptBlock
    }
    return $Task
}

<#
.SYNOPSIS
    Returns one or more AstNodes, filterable by types.

.NOTES
    Prior Art:
        Apparently there's a `Find-Ast` cmdlet in PowershellEditorServices.Command
        which gets loaded by VSCode and probably ISE as well.

.EXAMPLE
    Find the CommandAst in the given scriptblock.

    Find-AstNode { Write-Host 'Foobar' } -Type CommandAst

.EXAMPLE
    Find all CommandAsts in the given scriptblock.

    Find-AstNode { Write-Host 'Foobar'; Get-Date } -Type CommandAst -All

.EXAMPLE
    Find a CommandAst with a specific command name using the Query parameter.

    Find-AstNode { Write-Host 'Foobar'; Get-Date } -Type CommandAst -Query {
        $_.GetCommandName() -eq 'Get-Date'
    }
#>
function Find-AstNode {
    [CmdletBinding(DefaultParameterSetName='ByTabExpansion2Context')]
    param(
        [Parameter(Mandatory,ParameterSetName='ByScriptBlock',Position=0)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory,ParameterSetName='ByAst',Position=0)]
        [System.Management.Automation.Language.Ast] $Ast,

        [Parameter(ParameterSetName='ByScriptBlock',Position=1)]
        [Parameter(ParameterSetName='ByAst',Position=1)]
        [Parameter(ParameterSetName='ByTabExpansion2Context',Position=1)]
        [ArgumentCompleter({
            param(
                [string] $CommandName,
                [string] $ParameterName,
                [string] $WordToComplete,
                [System.Management.Automation.Language.CommandAst] $CommandAst,
                [System.Collections.IDictionary] $FakeBoundParameters
            )

            if (-not $script:FindAstNodeCompletionCache) {
                $script:FindAstNodeCompletionCache =
                    [System.Management.Automation.Language.Ast].Assembly.ExportedTypes |
                    Where-Object {
                        $_.BaseType -and (
                            $_.BaseType -eq [System.Management.Automation.Language.Ast] -or
                            $_.BaseType.IsSubclassOf([System.Management.Automation.Language.Ast])
                        )
                    } |
                    Select-Object -ExpandProperty Name |
                    Sort-Object
            }

            $Completions = $script:FindAstNodeCompletionCache |
                Where-Object {
                    $_.StartsWith($WordToComplete, [StringComparison]::InvariantCultureIgnoreCase)
                }

            if ($Completions.Count -gt 0) {
                return $Completions
            }
            return @()  # Prevent fallback autocomplete
        })]
        [string[]] $Type,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [scriptblock] $Query,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [switch] $All,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [switch] $Recurse,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(Mandatory,ParameterSetName='ByTabExpansion2Context')]
        [switch] $ContainsCursor,

        [Parameter(ParameterSetName='ByScriptBlock')]
        [Parameter(ParameterSetName='ByAst')]
        [Parameter(ParameterSetName='ByTabExpansion2Context')]
        [int] $CursorOffset
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByScriptBlock') {
        $Ast = $ScriptBlock.Ast
    }

    $HasContainsCursor = $PSBoundParameters.ContainsKey('ContainsCursor')
    $HasCursorOffset = $PSBoundParameters.ContainsKey('CursorOffset')

    if ($HasContainsCursor -and ((-not $HasCursorOffset) -or (-not $PSBoundParameters.ContainsKey('Ast')))) {
        $TabExpansion2Params = $null
        $Callstack = Get-PSCallStack | Where-Object { $_.Command -eq 'TabExpansion2' } | Select-Object -First 1
        if ($Callstack) {
            $TabExpansion2Params = $Callstack.InvocationInfo.BoundParameters
        }

        if ((-not $PSBoundParameters.ContainsKey('Ast')) -and $TabExpansion2Params -and $TabExpansion2Params.Ast) {
            $Ast = $TabExpansion2Params.Ast
        }

        if (
            $TabExpansion2Params -and
            $TabExpansion2Params.PositionOfCursor -and
            $null -ne $TabExpansion2Params.PositionOfCursor.Offset
        ) {
            $CursorOffset = [int] $TabExpansion2Params.PositionOfCursor.Offset
            $HasCursorOffset = $true
        }

        if (-not $HasCursorOffset) {
            Write-Error 'CursorOffset is required when ContainsCursor is specified and could not be resolved from TabExpansion2 context.'
            return
        }

        if (-not $Ast) {
            Write-Error 'Ast is required and could not be resolved from TabExpansion2 context.'
            return
        }
    }

    if ($HasCursorOffset -and -not $HasContainsCursor) {
        Write-Error 'ContainsCursor is required when CursorOffset is specified.'
        return
    }

    $HasCallerQuery = $PSBoundParameters.ContainsKey('Query')
    $TypeNames = if ($Type) { $Type } else { @() }

    if ($HasCallerQuery) {
        $OriginalQuery = $Query

        # Pass to Foreach-Object so query scriptblocks can reference $_.
        $HasParamBlockParameters =
            $null -ne $OriginalQuery.Ast.ParamBlock -and
            $OriginalQuery.Ast.ParamBlock.Parameters.Count -gt 0

        if ($HasParamBlockParameters) {
            $EvaluateQuery = {
                param($AstNode)
                & $OriginalQuery $AstNode
            }
        } else {
            $EvaluateQuery = {
                param($AstNode)
                $AstNode | ForEach-Object $OriginalQuery
            }
        }
    }

    $Query = {
        param($AstNode)

        if ($TypeNames.Count -gt 0) {
            $IsExpectedType = $false
            foreach ($T in $TypeNames) {
                if ($AstNode.GetType().Name -eq $T) {
                    $IsExpectedType = $true
                    break
                }
            }

            if (-not $IsExpectedType) {
                return $false
            }
        }

        if ($HasContainsCursor) {
            if ($CursorOffset -lt $AstNode.Extent.StartOffset -or
                $CursorOffset -gt $AstNode.Extent.EndOffset
            ) {
                return $false
            }
        }

        if ($HasCallerQuery) {
            return (& $EvaluateQuery $AstNode)
        }

        return $true
    }

    if ($All) {
        return $Ast.FindAll($Query, $Recurse)
    }

    return $Ast.Find($Query, $Recurse)
}


<#
.SYNOPSIS
    Extracts property declaration command tokens from a script block.

.DESCRIPTION
    Scans command invocations in a script block and returns a map of property declaration
    command tokens to their resolved names.

    This is a simple extraction helper for DSL syntax processing.
    Property declarations use the Name: Value form. Bare command names are ignored.

.EXAMPLE
    Extract property declarations from a script block.

    $styleScript = {
        FontSize: 16
        Margin: '2,4,6,8'
        Background: ButtonBackground -Resource
    }

    $propertyDeclarations = Get-PropertyDeclaration -ScriptBlock $styleScript
    # Returns: @{ 'FontSize:' = 'FontSize'; 'Margin:' = 'Margin'; 'Background:' = 'Background' }
#>
function Get-PropertyDeclaration {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[string, scriptblock]])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    $propertyDeclarationMap = [System.Collections.Generic.Dictionary[string, scriptblock]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $commandAsts = Find-AstNode `
        -ScriptBlock $ScriptBlock `
        -Type CommandAst `
        -All `
        -Recurse `
        -Query {
            param($AstNode)
            $CommandName = $AstNode.GetCommandName()
            return (
                $AstNode.CommandElements.Count -ge 1 -and
                $CommandName -ne $null -and
                $CommandName.Length -gt 1 -and
                $CommandName.EndsWith(':')
            )
        }

    foreach ($CommandAst in $CommandAsts) {
        $CommandToken = $CommandAst.GetCommandName()
        if (-not $PropertyDeclarationMap.ContainsKey($CommandToken)) {
            $PropertyDeclarationMap[$CommandToken] = $null
        }
    }

    return $PropertyDeclarationMap
}


<#
.SYNOPSIS
    Loads task declarations from a TaskFile.
#>
function Read-TaskFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $TaskFileScript = [scriptblock]::Create([System.IO.File]::ReadAllText($ResolvedPath))
    $TaskFunctions = Get-PropertyDeclaration -ScriptBlock $TaskFileScript

    if ($TaskFunctions.Count -eq 0) {
        throw "TaskFile '$ResolvedPath' does not declare any tasks."
    }

    foreach ($TaskName in @($TaskFunctions.Keys)) {
        $TaskFunctions[$TaskName] = $function:Task
    }

    $Tasks = @($TaskFileScript.InvokeWithContext($TaskFunctions, $null, @()))
    $TasksByName = [Dictionary[string, hashtable]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($TaskDefinition in $Tasks) {
        if ($TasksByName.ContainsKey($TaskDefinition.Name)) {
            throw "Task '$($TaskDefinition.Name)' is declared more than once."
        }

        $TasksByName.Add($TaskDefinition.Name, $TaskDefinition)
    }

    return [pscustomobject] @{
        DefaultTask = $Tasks[0].Name
        Tasks = $TasksByName
    }
}

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

        if ($Dag.Nodes -contains $TaskName) {
            return
        }

        $Dag.AddNode($TaskName)
        foreach ($Dependency in $Tasks[$TaskName].Dependencies) {
            & $AddTask $Dependency
            $Dag.AddEdge($Dependency, $TaskName)
        }
    }

    & $AddTask $Name
    if ($Dag.HasCycle()) {
        throw "Task dependency cycle detected for '$Name'."
    }

    return $Dag.GetTopologicalOrder()
}

<#
.SYNOPSIS
    Runs a task and its dependencies from a TaskFile.

.EXAMPLE
    please build

.EXAMPLE
    Invoke-PrettyPlease -TaskFile ./tasks.ps1 -Name test
#>
function Invoke-PrettyPlease {
    [CmdletBinding()]
    [Alias('pp', 'please')]
    param (
        [Parameter(Position=0)]
        [string] $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $TaskFile = (Join-Path $PWD 'TaskFile.ps1')
    )

    $TaskSet = Read-TaskFile -Path $TaskFile
    if ([string]::IsNullOrEmpty($Name)) {
        $Name = $TaskSet.DefaultTask
    }

    foreach ($TaskName in (Resolve-TaskOrder -Name $Name -Tasks $TaskSet.Tasks)) {
        & $TaskSet.Tasks[$TaskName].ScriptBlock
    }
}
