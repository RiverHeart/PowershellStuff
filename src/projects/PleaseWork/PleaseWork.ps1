using namespace System.Collections.Generic

# Directed Acyclic Graph
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

<#
.SYNOPSIS
    Registers one task definition without writing it to the output pipeline.
#>
function Task {
    [CmdletBinding(PositionalBinding=$false)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.Language.CommentHelpInfo] $Help,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[hashtable]] $Registry,

        [Parameter(ValueFromRemainingArguments)]
        [object[]] $Arguments
    )

    if ($Arguments.Length -eq 0) {
        throw 'At least one argument (the scriptblock) is required.'
    }

    $ScriptBlock = $Arguments[-1]
    if (-not ($ScriptBlock -is [scriptblock])) {
        throw [System.ArgumentException]::new('The last argument must be a scriptblock.')
    }

    if ($Arguments.Length -gt 1) {
        [string[]] $Dependencies = $Arguments[0..($Arguments.Length - 2)]
    } else {
        [string[]] $Dependencies = @()
    }

    $Registry.Add(@{
        Name = $Name
        Help = $Help
        Dependencies = $Dependencies
        ScriptBlock = $ScriptBlock
    })
}

<#
.SYNOPSIS
    Parses comment-based help associated with a task.
#>
function Get-TaskHelp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Comments
    )

    if ($Comments.Count -eq 0) {
        return
    }

    $HelpSource = ($Comments -join [Environment]::NewLine) +
        "`nfunction __PleaseWorkTaskHelp {}`n"
    $HelpTokens = $null
    $HelpErrors = $null
    $HelpAst = [System.Management.Automation.Language.Parser]::ParseInput(
        $HelpSource,
        [ref] $HelpTokens,
        [ref] $HelpErrors
    )
    $FunctionAst = $HelpAst.Find({
            param ($AstNode)
            $AstNode -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $false)
    return $FunctionAst.GetHelpContent()
}

<#
.SYNOPSIS
    Parses ordered task declarations from a scriptblock without invoking it.
#>
function Get-TaskDeclaration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    $SourceText = $ScriptBlock.Ast.Extent.Text
    $Tokens = $null
    $ParseErrors = $null
    $ParsedAst = [System.Management.Automation.Language.Parser]::ParseInput(
        $SourceText,
        [ref] $Tokens,
        [ref] $ParseErrors
    )
    $CommentTokens = @($Tokens | Where-Object {
            $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment
        })

    $TaskNames = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Statement in $ParsedAst.EndBlock.Statements) {
        # Only top-level, single-command pipelines can be task declarations.
        if (-not ($Statement -is [System.Management.Automation.Language.PipelineAst]) -or
            $Statement.PipelineElements.Count -ne 1 -or
            -not ($Statement.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst])
        ) {
            continue
        }

        $CommandAst = $Statement.PipelineElements[0]
        $CommandToken = $CommandAst.GetCommandName()
        # The trailing colon distinguishes task declarations from ordinary commands.
        if ([string]::IsNullOrEmpty($CommandToken) -or
            -not $CommandToken.EndsWith(':')
        ) {
            continue
        }

        $TaskName = $CommandToken.TrimEnd(':')
        if ([string]::IsNullOrEmpty($TaskName)) {
            throw 'Task names cannot be empty.'
        }
        if (-not $TaskNames.Add($TaskName)) {
            throw "Task '$TaskName' is declared more than once."
        }

        $CommandElements = $CommandAst.CommandElements
        if ($CommandElements.Count -lt 2 -or
            -not ($CommandElements[-1] -is [System.Management.Automation.Language.ScriptBlockExpressionAst])
        ) {
            throw "Task '$TaskName' must end with a scriptblock body."
        }

        if ($CommandElements.Count -gt 2) {
            $Dependencies = [List[string]]::new()
            foreach ($DependencyAst in $CommandElements[1..($CommandElements.Count - 2)]) {
                if (
                    -not ($DependencyAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) -or
                    $DependencyAst.StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::BareWord
                ) {
                    throw "Dependencies for task '$TaskName' must be bare task names."
                }

                $Dependencies.Add($DependencyAst.Value)
            }
        } else {
            $Dependencies = [List[string]]::new()
        }

        $Comments = [List[string]]::new()
        $CommentBoundary = $CommandAst.Extent.StartOffset
        foreach ($CommentToken in ($CommentTokens |
                Where-Object { $_.Extent.EndOffset -le $CommentBoundary } |
                Sort-Object { $_.Extent.StartOffset } -Descending)) {
            $Gap = $SourceText.Substring(
                $CommentToken.Extent.EndOffset,
                $CommentBoundary - $CommentToken.Extent.EndOffset
            )
            if (-not [string]::IsNullOrWhiteSpace($Gap)) {
                break
            }

            $Comments.Insert(0, $CommentToken.Text)
            $CommentBoundary = $CommentToken.Extent.StartOffset
        }

        $TaskHelp = Get-TaskHelp -Comments $Comments.ToArray()
        [pscustomobject] @{
            Name = $TaskName
            CommandToken = $CommandToken
            Dependencies = $Dependencies.ToArray()
            Comments = $Comments.ToArray()
            Help = $TaskHelp
        }
    }
}


<#
.SYNOPSIS
    Resolves an explicit TaskFile or discovers one in the current directory hierarchy.
#>
function Resolve-TaskFilePath {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Path
    )

    if (-not [string]::IsNullOrEmpty($Path)) {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    }

    if ($PWD.Provider.Name -ne 'FileSystem') {
        throw 'TaskFile discovery requires a FileSystem location.'
    }

    $Directory = [System.IO.DirectoryInfo]::new($PWD.ProviderPath)
    while ($null -ne $Directory) {
        $Candidate = Join-Path $Directory.FullName 'TaskFile.ps1'
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $Candidate).ProviderPath
        }

        $Directory = $Directory.Parent
    }

    throw "Could not find 'TaskFile.ps1' in '$($PWD.ProviderPath)' or any parent directory."
}

<#
.SYNOPSIS
    Reads ordered TaskFile declaration metadata without invoking the TaskFile.
#>
function Get-TaskFileDeclaration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $TaskFileScript = [scriptblock]::Create([System.IO.File]::ReadAllText($ResolvedPath))
    return Get-TaskDeclaration -ScriptBlock $TaskFileScript
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
    $Declarations = @(Get-TaskDeclaration -ScriptBlock $TaskFileScript)

    if ($Declarations.Count -eq 0) {
        throw "TaskFile '$ResolvedPath' does not declare any tasks."
    }

    # Keep the TaskFile definition scope alive after this function returns. Dot-sourcing
    # into the module binds the original task bodies to its variables and functions.
    $TaskFileModule = New-Module `
        -ArgumentList $TaskFileScript, $Declarations, $function:Task `
        -ErrorAction Stop `
        -ScriptBlock {
            param ($ScriptBlock, $TaskDeclarations, $TaskRegistrar)

            $script:RegisteredTasks = [List[hashtable]]::new()
            foreach ($Declaration in $TaskDeclarations) {
                $TaskName = $Declaration.Name
                $TaskHelp = $Declaration.Help
                $TaskCommand = {
                    [CmdletBinding()]
                    param (
                        [Parameter(ValueFromRemainingArguments)]
                        [object[]] $Arguments
                    )

                    & $TaskRegistrar `
                        -Name $TaskName `
                        -Help $TaskHelp `
                        -Registry $script:RegisteredTasks `
                        -Arguments $Arguments
                }.GetNewClosure()

                Set-Item -LiteralPath "Function:$($Declaration.CommandToken)" -Value $TaskCommand
            }

            $BoundScriptBlock = $ExecutionContext.SessionState.Module.NewBoundScriptBlock($ScriptBlock)
            $ErrorActionPreference = 'Stop'
            $null = @(. $BoundScriptBlock)
        }
    $Tasks = @(& $TaskFileModule { $script:RegisteredTasks })
    $TasksByName = [Dictionary[string, hashtable]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($TaskDefinition in $Tasks) {
        if ($TasksByName.ContainsKey($TaskDefinition.Name)) {
            throw "Task '$($TaskDefinition.Name)' is declared more than once."
        }

        $TasksByName.Add($TaskDefinition.Name, $TaskDefinition)
    }

    return [pscustomobject] @{
        DefaultTask = $Tasks[0].Name
        TaskNames = [string[]] $Tasks.Name
        Tasks = $TasksByName
        Module = $TaskFileModule
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

<#
.SYNOPSIS
    Invokes one task with explicit context and records its result.
#>
function Invoke-PleaseWorkTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Context,

        [Parameter(Mandatory)]
        [ref] $Result
    )

    $Variables = [List[System.Management.Automation.PSVariable]]::new()
    $Variables.Add(
        [System.Management.Automation.PSVariable]::new('ErrorActionPreference', 'Stop')
    )
    foreach ($VariableName in $Context.Keys) {
        if ($VariableName -eq 'ErrorActionPreference') {
            continue
        }
        $Variables.Add(
            [System.Management.Automation.PSVariable]::new(
                [string] $VariableName,
                $Context[$VariableName]
            )
        )
    }

    $StartedAt = [datetime]::UtcNow
    $global:LASTEXITCODE = 0
    try {
        # InvokeWithContext returns collected output only after successful completion. If the
        # scriptblock terminates, output written before the error is not available to the caller.
        $ScriptBlock.InvokeWithContext($null, $Variables, @())
    } catch {
        $TaskError = $_
        $TaskException = $_.Exception
        if ($null -ne $TaskException.InnerException) {
            $TaskException = $TaskException.InnerException
            if ($TaskException -is [System.Management.Automation.RuntimeException] -and
                $null -ne $TaskException.ErrorRecord
            ) {
                $TaskError = $TaskException.ErrorRecord
            }
        }

        $FinishedAt = [datetime]::UtcNow
        $Result.Value = [pscustomobject] @{
            TaskName = $Name
            Succeeded = $false
            ExitCode = [int] $global:LASTEXITCODE
            Error = $TaskError
            StartedAt = $StartedAt
            FinishedAt = $FinishedAt
            Duration = $FinishedAt - $StartedAt
        }
        throw $TaskException
    }

    $FinishedAt = [datetime]::UtcNow
    $ExitCode = [int] $global:LASTEXITCODE
    $Result.Value = [pscustomobject] @{
        TaskName = $Name
        Succeeded = $ExitCode -eq 0
        ExitCode = $ExitCode
        Error = $null
        StartedAt = $StartedAt
        FinishedAt = $FinishedAt
        Duration = $FinishedAt - $StartedAt
    }
}

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
    param (
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
        [switch] $PassThru
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

    $TaskContext = @{
        TaskFilePath = $TaskFilePath
        TaskFileRoot = $TaskFileRoot
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
