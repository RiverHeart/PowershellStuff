using namespace System
using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

# MARK: NP_CORRECT
#----------------------

class NitpickCorrection {
    [psobject] $TextEdit
    [int] $StartLineNumber
    [int] $EndLineNumber
    [int] $StartColumnNumber
    [int] $EndColumnNumber
    [int] $StartOffset = -1
    [int] $EndOffset = -1
    [bool] $HasOffsets
    [string] $ExpectedText
    [string] $Applicability = 'Safe'
    [string] $ChangeSetId
    [string] $RuleId
    [string] $RuleName
    [string] $ReplacementText
    [string] $FilePathOrContext
    [string] $Description

    NitpickCorrection(
        [IScriptExtent] $ViolationExtent,
        [string] $replacementText,
        [string] $filePathOrContext,
        [string] $description
    ) {
        $this.TextEdit = New-AstTextEdit `
            -Extent $ViolationExtent `
            -ReplacementText $replacementText `
            -Reason $description
        $this.SetTextEditProjections()
        $this.ReplacementText = $replacementText
        $this.FilePathOrContext = $filePathOrContext
        $this.Description = $description
        $this.Validate()
    }

    NitpickCorrection(
        [int] $startLineNumber,
        [int] $endLineNumber,
        [int] $startColumnNumber,
        [int] $endColumnNumber,
        [string] $replacementText,
        [string] $filePathOrContext,
        [string] $description
    ) {
        $this.StartLineNumber = $startLineNumber
        $this.EndLineNumber = $endLineNumber
        $this.StartColumnNumber = $startColumnNumber
        $this.EndColumnNumber = $endColumnNumber
        $this.ReplacementText = $replacementText
        $this.FilePathOrContext = $filePathOrContext
        $this.Description = $description
        $this.Validate()
    }

    NitpickCorrection([hashtable] $properties) {
        if ($properties.ContainsKey('TextEdit')) {
            $this.TextEdit = $properties.TextEdit
            $this.SetTextEditProjections()
        } else {
            $this.StartLineNumber = $properties.StartLineNumber
            $this.EndLineNumber = $properties.EndLineNumber
            $this.StartColumnNumber = $properties.StartColumnNumber
            $this.EndColumnNumber = $properties.EndColumnNumber
        }
        if ($properties.ContainsKey('Applicability')) {
            $this.Applicability = $properties.Applicability
        }
        if ($properties.ContainsKey('ChangeSetId')) {
            $this.ChangeSetId = $properties.ChangeSetId
        }
        if ($properties.ContainsKey('RuleName')) {
            $this.RuleName = $properties.RuleName
        }
        if (-not $this.TextEdit) {
            $this.ReplacementText = $properties.ReplacementText
        }
        $this.FilePathOrContext = $properties.FilePathOrContext
        $this.Description = $properties.Description
        $this.Validate()
    }

    hidden [void] SetTextEditProjections() {
        $this.StartLineNumber = $this.TextEdit.StartLineNumber
        $this.EndLineNumber = $this.TextEdit.EndLineNumber
        $this.StartColumnNumber = $this.TextEdit.StartColumnNumber
        $this.EndColumnNumber = $this.TextEdit.EndColumnNumber
        $this.StartOffset = $this.TextEdit.StartOffset
        $this.EndOffset = $this.TextEdit.EndOffset
        $this.HasOffsets = $true
        $this.ExpectedText = $this.TextEdit.ExpectedText
        $this.ReplacementText = $this.TextEdit.ReplacementText
    }

    hidden [void] Validate() {
        if ($this.StartLineNumber -lt 1 -or $this.EndLineNumber -lt 1) {
            throw 'Line numbers must be greater than zero.'
        }
        if ($this.StartColumnNumber -lt 1 -or $this.EndColumnNumber -lt 1) {
            throw 'Column numbers must be greater than zero.'
        }
        if ($this.EndLineNumber -lt $this.StartLineNumber -or
            ($this.EndLineNumber -eq $this.StartLineNumber -and
                $this.EndColumnNumber -lt $this.StartColumnNumber)
        ) {
            throw 'The correction end position must not precede its start position.'
        }
        if ($this.Applicability -notin 'Safe', 'Review', 'Unsafe') {
            throw "Applicability must be Safe, Review, or Unsafe. Received '$($this.Applicability)'."
        }
    }

    <#
    .SYNOPSIS
        Converts the NitpickCorrection instance to a CorrectionExtent object.
    .OUTPUTS
        [object] # Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent
    #>
    [object] ToCorrectionExtent() {
        # Using `New-Object` to avoid type resolution issues at parse time
        $Result = New-Object 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent' -ArgumentList (
            $this.StartLineNumber,
            $this.EndLineNumber,
            $this.StartColumnNumber,
            $this.EndColumnNumber,
            $this.ReplacementText,
            $this.FilePathOrContext,
            $this.Description
        )
        return $Result
    }

}

# MARK: NP_FINDING
#------------------

class NitpickFinding {
    [IScriptExtent] $ViolationExtent
    [string] $Message
    [string] $RuleId
    [string] $RuleName
    [string] $RuleSuppressionID
    [string] $Severity
    [NitpickCorrection[]] $Corrections
    [string] $Location

    NitpickFinding(
        [IScriptExtent] $ViolationExtent,
        [string] $replacementText,
        [string] $filePathOrContext,
        [string] $description
    ) {
        $this.ViolationExtent = $ViolationExtent
        $this.Message = $replacementText
        $this.RuleName = $filePathOrContext
        $this.RuleSuppressionID = $description
        $this.Severity = $description
        $this.Corrections = @()
        $this.Location =
            $this.ViolationExtent.File + ':' +
            $this.ViolationExtent.StartLineNumber + ':' +
            $this.ViolationExtent.StartColumnNumber
    }

    NitpickFinding([hashtable] $properties) {
        $this.ViolationExtent = $properties.ViolationExtent
        $this.Message = $properties.Message
        $this.RuleName = $properties.RuleName
        $this.RuleSuppressionID = $properties.RuleSuppressionID
        $this.Severity = $properties.Severity
        $this.Corrections = $properties.Corrections
        $LocationPath = if ($this.ViolationExtent.File) {
            $this.ViolationExtent.File
        } elseif ($properties.ScriptPath) {
            $properties.ScriptPath
        } else {
            '<ScriptBlock>'
        }
        $this.Location =
            $LocationPath + ':' +
            $this.ViolationExtent.StartLineNumber + ':' +
            $this.ViolationExtent.StartColumnNumber
    }

    [object] ToDiagnosticRecord() {
        # Using `New-Object` to avoid type resolution issues at parse time
        $CorrectionExtents = New-Object 'System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]'
        foreach ($Correction in $this.Corrections) {
            # ScriptAnalyzer cannot enforce all-or-nothing selection of a change set.
            if ($Correction.ChangeSetId) {
                continue
            }
            $CorrectionExtents.Add($Correction.ToCorrectionExtent())
        }

        $Result = New-Object 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord' -ArgumentList (
            $this.Message,
            $this.ViolationExtent,
            $this.RuleName,
            $this.Severity,
            $this.ViolationExtent.File,
            $this.RuleSuppressionID,
            $CorrectionExtents.PSObject.BaseObject
        )
        return $Result
    }

    [string] ToString() {
        return '{0}: {1} {2}: {3}' -f `
            $this.Location,
            $this.Severity,
            (Get-NitpickRuleLabel -InputObject $this),
            $this.Message
    }
}

Update-TypeData `
    -TypeName 'NitpickFinding' `
    -DefaultDisplayPropertySet 'Location', 'RuleId', 'Message' `
    -Force


# MARK: NP_SUMMARY
#------------------

class NitpickSummary {
    [int] $TargetCount
    [int] $RuleCount
    [int] $FindingCount
    [int] $ErrorCount
    [int] $WarningCount
    [int] $InformationCount
    [int] $FindingsWithCommittedCorrectionsCount
    [int] $SkippedCorrectionCount
    [int] $ConflictedTargetCount
    [int] $FailedTargetCount
    [timespan] $Duration

    [string] ToString() {
        $FindingLabel = if ($this.FindingCount -eq 1) { 'finding' } else { 'findings' }
        $TargetLabel = if ($this.TargetCount -eq 1) { 'target' } else { 'targets' }

        return '{0} {1} ({2} errors, {3} warnings, {4} information) across {5} {6} in {7:N0} ms' -f `
            $this.FindingCount,
            $FindingLabel,
            $this.ErrorCount,
            $this.WarningCount,
            $this.InformationCount,
            $this.TargetCount,
            $TargetLabel,
            $this.Duration.TotalMilliseconds
    }
}


# MARK: NP_RULE
#------------------

class NitpickRule {
    [string] $Name
    [string] $Namespace
    [string] $Id
    [string] $Category
    [bool] $EditorEnabled
    [string] $CallableType
    [object] $Callable
    [string] $Source
    [string] $Description
    [string] $Severity
    [string] $Explanation
    [string[]] $IncludePath
    [string[]] $ExcludePath

    NitpickRule([object] $TargetCallable, [hashtable] $Overrides) {
        if ($TargetCallable -is [string]) {
            try {
                $TargetCallable = Get-Command `
                    -Name $TargetCallable `
                    -CommandType Function, Cmdlet `
                    -ErrorAction Stop
            } catch {
                throw "Failed to resolve command: $TargetCallable"
            }
        }

        Assert-CallableSignature `
            -Callable $TargetCallable `
            -RequiredParams 'ScriptBlockAst' `
            -ErrorAction Stop

        $this.Category = 'Other'
        $this.EditorEnabled = $true
        if ($TargetCallable -is [scriptblock]) {
            $this.CallableType = 'ScriptBlock'
            $this.Callable = $TargetCallable
            $this.Namespace = 'Local'
        } else {
            $this.Name = if ($TargetCallable.Noun) {
                $TargetCallable.Noun
            } else {
                $TargetCallable.Name
            }
            $this.CallableType = 'Function'
            $this.Callable = $TargetCallable
            $this.Source = $TargetCallable.ModuleName
            $this.Namespace = if ($TargetCallable.ModuleName) {
                $TargetCallable.ModuleName
            } else {
                'Local'
            }
        }

        $HasDetails = $TargetCallable |
            Get-CallableParameter -Name 'Details' -Type 'SwitchParameter'

        if ($HasDetails) {
            $Details = & $TargetCallable -Details
            foreach ($Property in 'Name', 'Category', 'EditorEnabled', 'Source', 'Description', 'Severity', 'Explanation', 'IncludePath', 'ExcludePath') {
                if ($null -ne $Details.$Property) {
                    $this.$Property = $Details.$Property
                }
            }
        }

        foreach ($Property in 'Name', 'Namespace', 'Category', 'EditorEnabled', 'Source', 'Description', 'Severity', 'Explanation') {
            if ($Overrides.ContainsKey($Property)) {
                $this.$Property = $Overrides[$Property]
            }
        }

        if ($TargetCallable -is [scriptblock] -and (-not $this.Name -or -not $this.Source)) {
            throw 'Name and Source are mandatory when using a scriptblock.'
        }
        if ($TargetCallable -isnot [scriptblock] -and -not $this.Source) {
            throw 'Source is mandatory for non-module functions/cmdlets.'
        }

        Assert-NitpickIdentitySegment -Value $this.Name -SegmentType Name
        Assert-NitpickIdentitySegment -Value $this.Namespace -SegmentType Namespace
        $this.Id = '{0}/{1}' -f $this.Namespace, $this.Name
    }

    <#
    .SYNOPSIS
        Determines if the rule applies to the specified file path.
    .PARAMETER FilePath
        The file path to check against the rule's include and exclude patterns.
    .OUTPUTS
        [bool]
    #>
    [bool] AppliesToPath([string] $FilePath) {
        if ([string]::IsNullOrEmpty($FilePath)) {
            return $true
        }

        $NormalizedPath = $FilePath.Replace('\', '/')
        $IsIncluded = $this.IncludePath.Count -eq 0
        foreach ($Pattern in $this.IncludePath) {
            if ($NormalizedPath -like $Pattern) {
                $IsIncluded = $true
                break
            }
        }

        if (-not $IsIncluded) {
            return $false
        }

        foreach ($Pattern in $this.ExcludePath) {
            if ($NormalizedPath -like $Pattern) {
                return $false
            }
        }

        return $true
    }

    <#
    .SYNOPSIS
        Invokes the rule against the specified ScriptBlockAst.
    .DESCRIPTION
        Assigns descriptor-owned identity to native findings and nested corrections.
        Non-native outputs, including explicit DiagnosticRecords, are returned unchanged.
    .PARAMETER Ast
        The ScriptBlockAst to check against the rule.
    .OUTPUTS
        [object[]] # NitpickFinding or DiagnosticRecord instances
    #>
    [object[]] Invoke([ScriptBlockAst] $Ast) {
        return $this.Invoke($Ast, @{
            Caller = 'Nitpick'
            File = $Ast.Extent.File
            RuleBehavior = @{
                SearchNestedScriptBlocks = $true
                OutputType = 'NitpickFinding'
            }
        })
    }

    <#
    .SYNOPSIS
        Invokes the rule against the specified ScriptBlockAst.
    .PARAMETER Ast
        The ScriptBlockAst to check against the rule.
    .PARAMETER Context
        The context dictionary to pass to the rule invocation.
    .OUTPUTS
        [object[]] # NitpickFinding or DiagnosticRecord instances
    #>
    [object[]] Invoke(
        [ScriptBlockAst] $Ast,
        [System.Collections.IDictionary] $Context
    ) {
        $Parameters = @{ ScriptBlockAst = $Ast }
        if (Get-CallableParameter -Callable $this.Callable -Name Context) {
            $Parameters.Context = $Context
        }
        [object[]] $Results = @(& $this.Callable @Parameters)
        foreach ($Finding in $Results) {
            if ($Finding -isnot [NitpickFinding]) {
                continue
            }
            $Finding.RuleId = $this.Id
            $Finding.RuleName = $this.Name
            $Finding.RuleSuppressionID = $this.Name
            foreach ($Correction in $Finding.Corrections) {
                $Correction.RuleId = $this.Id
                $Correction.RuleName = $this.Name
            }
        }
        return $Results
    }
}

Update-TypeData `
    -TypeName 'NitpickRule' `
    -DefaultDisplayPropertySet 'Name', 'Category', 'Severity', 'Description' `
    -Force

# MARK: NP_DAG
#----------------------

# NOTE: Copied wholesale from PleaseWork's DirectedAcyclicGraph (src/Classes/DirectedAcyclicGraph.ps1)
# rather than taken as a module dependency, consistent with keeping generic reusable utilities
# out of Nitpick's required-module surface. Used to detect cycles in manifest-declared
# RuleModules graphs before any supporting module is imported.
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

# MARK: TRANSFORM

# NOTE: PowerShell's `Attribute` suffix omission happens during parse-time type resolution,
# and because this class lives in a separately parsed file. Without colocating the class,
# which is anti-DRY, the `Attribute` suffix must either be included or omitted so an exact
# type lookup can be performed. In this case, I'm choosing to omit the suffix in favor of a
# nicer decorator name.
class ScriptBlockAstTransform : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics] $EngineIntrinsics, [object] $Input) {
        if ($Input -is [ScriptBlock]) {
            return $Input.Ast
        }
        if ($Input -is [string]) {
            return [System.Management.Automation.Language.Parser]::ParseInput($Input, [ref] $null, [ref] $null)
        }
        return $Input
    }
}

class NitpickCorrectionProposal {
    [string] $Path = '<ScriptBlock>'
    [psobject] $Document
    [string] $OriginalFingerprint
    [string] $Status = 'NoChanges'
    [string] $OriginalText
    [NitpickFinding[]] $OriginalFindings = @()
    [string] $CandidateText
    [NitpickFinding[]] $CandidateFindings = @()
    [bool] $WasReanalyzed
    [NitpickCorrection[]] $AcceptedCorrections = @()
    [object[]] $SkippedCorrections = @()
    [object[]] $Conflicts = @()
    [object[]] $ParseErrors = @()
    [string] $Diff
}

class NitpickCorrectionApplication {
    [string] $Status = 'NotAttempted'
    [NitpickCorrection[]] $CommittedCorrections = @()
    [psobject] $WriteResult
    [ErrorRecord] $ErrorRecord
}

class NitpickCorrectionReport {
    [string] $AnalysisSource = 'None'
    [string] $EffectiveText
    [NitpickFinding[]] $EffectiveFindings = @()
    [NitpickFinding[]] $FindingsWithCommittedCorrections = @()
}

class NitpickCorrectionResult {
    [string] $Path
    [NitpickCorrectionProposal] $Proposal
    [NitpickCorrectionApplication] $Application
    [NitpickCorrectionReport] $Report

    NitpickCorrectionResult(
        [string] $Path,
        [NitpickCorrectionProposal] $Proposal,
        [NitpickCorrectionApplication] $Application,
        [NitpickCorrectionReport] $Report
    ) {
        if ($null -eq $Application -or $null -eq $Report) {
            throw 'A correction result requires application and report data.'
        }
        $this.Path = $Path
        $this.Proposal = $Proposal
        $this.Application = $Application
        $this.Report = $Report
    }
}

$Paths = @(
    'Private'
    'Public'
)

foreach ($Path in $Paths) {
    Get-ChildItem -Path "$ModuleRoot/$Path" -Recurse -Filter '*.ps1' |
        Where-Object { $_ -notlike '*.kicker.ps1'} |
        ForEach-Object {
            . $_.FullName
        }
}


# Register built-in rules
# Get-ChildItem -Path "$ModuleRoot/Public/Rules" -Recurse -Filter '*.ps1' |
#     ForEach-Object {
#         Register-Nitpick -
#     }
