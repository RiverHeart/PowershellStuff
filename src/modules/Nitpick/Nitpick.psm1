using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

# MARK: NP_CORRECT
#----------------------

class NitpickCorrection {
    # One correction is one complete fix for a finding: its text edits apply
    # all-or-nothing. Line/column fields project the first edit for display;
    # ReplacementText projects only single-edit corrections for interop.
    [psobject[]] $TextEdits = @()
    [int] $StartLineNumber
    [int] $EndLineNumber
    [int] $StartColumnNumber
    [int] $EndColumnNumber
    [string] $Applicability = 'Safe'
    [string] $RuleId
    [string] $ReplacementText
    [string] $FilePathOrContext
    [string] $Description

    NitpickCorrection(
        [IScriptExtent] $ViolationExtent,
        [string] $replacementText,
        [string] $filePathOrContext,
        [string] $description
    ) {
        $this.TextEdits = @(New-AstTextEdit `
            -Extent $ViolationExtent `
            -ReplacementText $replacementText `
            -Reason $description)
        $this.SetTextEditProjections()
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
        foreach ($Key in $properties.Keys) {
            if (-not $this.PSObject.Properties[$Key]) {
                throw "Unknown NitpickCorrection constructor key '$Key'. Rule identity uses the qualified RuleId."
            }
        }

        if ($properties.ContainsKey('TextEdits')) {
            $this.TextEdits = @($properties.TextEdits)
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

        if ($properties.ContainsKey('RuleId')) {
            Assert-NitpickRuleId -Value $properties.RuleId
            $this.RuleId = $properties.RuleId
        }

        if ($this.TextEdits.Count -eq 0) {
            $this.ReplacementText = $properties.ReplacementText
        }

        $this.FilePathOrContext = $properties.FilePathOrContext
        $this.Description = $properties.Description
        $this.Validate()
    }

    hidden [void] SetTextEditProjections() {
        $Primary = $this.TextEdits[0]
        $this.StartLineNumber = $Primary.StartLineNumber
        $this.EndLineNumber = $Primary.EndLineNumber
        $this.StartColumnNumber = $Primary.StartColumnNumber
        $this.EndColumnNumber = $Primary.EndColumnNumber
        $this.ReplacementText = if ($this.TextEdits.Count -eq 1) {
            $Primary.ReplacementText
        } else {
            $null
        }
    }

    hidden [void] Validate() {
        foreach ($Edit in $this.TextEdits) {
            if ($null -eq $Edit -or $Edit.GetType().Name -ne 'AstTextEdit') {
                throw 'TextEdits must contain only AstEditor AstTextEdit objects.'
            }
        }

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
        if ($this.TextEdits.Count -gt 1) {
            throw 'A multi-edit correction cannot be converted to a single PSScriptAnalyzer CorrectionExtent.'
        }

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
    [string] $Severity
    [NitpickCorrection[]] $Corrections
    [string] $Location

    NitpickFinding([hashtable] $properties) {
        foreach ($Key in $properties.Keys) {
            # ScriptPath, Explanation, and RunCondition are accepted helper inputs
            # that are not stored as finding properties.
            if (-not ($this.PSObject.Properties[$Key] -or
                $Key -in 'ScriptPath', 'Explanation', 'RunCondition')) {
                throw "Unknown NitpickFinding constructor key '$Key'. Rule identity uses the qualified RuleId."
            }
        }
        Assert-NitpickRuleId -Value $properties.RuleId
        $this.RuleId = $properties.RuleId
        $this.ViolationExtent = $properties.ViolationExtent
        $this.Message = $properties.Message
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
        Assert-NitpickRuleId -Value $this.RuleId
        $LocalName = $this.RuleId.Split('/')[1]

        # Using `New-Object` to avoid type resolution issues at parse time
        $CorrectionExtents = New-Object 'System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]'

        foreach ($Correction in $this.Corrections) {
            # ScriptAnalyzer cannot enforce all-or-nothing application of a
            # multi-edit fix, so only single-edit corrections are exported.
            if ($Correction.TextEdits.Count -gt 1) {
                continue
            }
            $CorrectionExtents.Add($Correction.ToCorrectionExtent())
        }

        $Result = New-Object 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord' -ArgumentList (
            $this.Message,
            $this.ViolationExtent,
            $LocalName,
            $this.Severity,
            $this.ViolationExtent.File,
            $LocalName,
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
    [string] $FixMode = 'Off'
    [int] $FindingCount
    [int] $ErrorCount
    [int] $WarningCount
    [int] $InformationCount
    [int] $CorrectedFindingCount
    [int] $CorrectableFindingCount
    [int] $UndecidedFindingCount
    [int] $UnresolvedFindingCount
    [int] $SkippedFindingCount
    [int] $ConflictedTargetCount
    [int] $FailedTargetCount
    [timespan] $Duration

    [string] ToString() {
        $FindingLabel = if ($this.FindingCount -eq 1) { 'finding' } else { 'findings' }
        $TargetLabel = if ($this.TargetCount -eq 1) { 'target' } else { 'targets' }

        # FindingCount and the severity counters describe detected findings; zero severities are omitted.
        $SeverityParts = @(
            if ($this.ErrorCount -gt 0) {
                '{0} {1}' -f $this.ErrorCount, $(if ($this.ErrorCount -eq 1) { 'error' } else { 'errors' })
            }
            if ($this.WarningCount -gt 0) {
                '{0} {1}' -f $this.WarningCount, $(if ($this.WarningCount -eq 1) { 'warning' } else { 'warnings' })
            }
            if ($this.InformationCount -gt 0) {
                '{0} information' -f $this.InformationCount
            }
        )

        # The correction clause appears only in fix modes, labeled by whichever outcome is in play.
        $CorrectionParts = @(
            if ($this.FixMode -ne 'Off') {
                if ($this.CorrectedFindingCount -gt 0) {
                    '{0} corrected' -f $this.CorrectedFindingCount
                }
                if ($this.CorrectableFindingCount -gt 0) {
                    '{0} correctable' -f $this.CorrectableFindingCount
                }
                if ($this.UndecidedFindingCount -gt 0) {
                    '{0} undecided' -f $this.UndecidedFindingCount
                }
                '{0} unresolved' -f $this.UnresolvedFindingCount
            }
        )

        $Groups = @(
            if ($SeverityParts.Count -gt 0) { $SeverityParts -join ', ' }
            if ($CorrectionParts.Count -gt 0) { $CorrectionParts -join ', ' }
        )
        $Detail = if ($Groups.Count -gt 0) { ' ({0})' -f ($Groups -join '; ') } else { '' }

        # Undecided findings need a human choice; point at the mode that offers one.
        $Hint = if ($this.UndecidedFindingCount -gt 0 -and $this.FixMode -ne 'Guided') {
            '. Use -FixMode Guided to choose between alternative or non-Safe corrections.'
        } else {
            ''
        }

        return '{0} {1}{2} across {3} {4} in {5:N0} ms{6}' -f `
            $this.FindingCount,
            $FindingLabel,
            $Detail,
            $this.TargetCount,
            $TargetLabel,
            $this.Duration.TotalMilliseconds,
            $Hint
    }
}


# MARK: NP_RULE
#------------------

class NitpickRuleInvocationResult {
    [string] $Status
    [object[]] $Results

    NitpickRuleInvocationResult([string] $Status, [object[]] $Results) {
        $this.Status = $Status
        $this.Results = $Results
    }
}

class NitpickRule {
    # Opaque in-process marker for coordinator dispatch; not an authorization boundary.
    static hidden [object] $CoordinatorDispatchToken = [object]::new()

    [string] $Name
    [string] $Namespace
    [string] $Id
    [string] $Category
    [bool] $EditorEnabled
    [string] $CallableType
    [type] $DispatchType
    [string] $DispatchParameterName
    [object] $Callable
    [string] $Source
    [string] $Description
    [string] $Severity
    [string] $Explanation
    [string[]] $IncludePath
    [string[]] $ExcludePath
    [scriptblock] $Applicability
    [version] $MinimumAnalysisHostVersion
    [hashtable] $Settings

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

        $DispatchSignature = Resolve-NitpickDispatchSignature `
            -Callable $TargetCallable `
            -ErrorAction Stop

        $this.DispatchType = $DispatchSignature.DispatchType
        $this.DispatchParameterName = $DispatchSignature.DispatchParameterName
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

        $ExecutionMetadata = @{
            Applicability = $null
            MinimumAnalysisHostVersion = $null
            Settings = $null
        }

        if ($HasDetails) {
            $Details = & $TargetCallable -Details
            foreach ($Property in 'Name', 'Category', 'EditorEnabled', 'Source', 'Description', 'Severity', 'Explanation', 'IncludePath', 'ExcludePath') {
                if ($null -ne $Details.$Property) {
                    $this.$Property = $Details.$Property
                }
            }

            foreach ($Property in @($ExecutionMetadata.Keys)) {
                $ExecutionMetadata[$Property] = $Details.$Property
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

        foreach ($Property in @($ExecutionMetadata.Keys)) {
            if ($Overrides.ContainsKey($Property)) {
                $ExecutionMetadata[$Property] = $Overrides[$Property]
            }
        }

        if ($null -ne $ExecutionMetadata.Applicability -and
            $ExecutionMetadata.Applicability -isnot [scriptblock]
        ) {
            throw [ArgumentException]::new("Rule '$($this.Id)' Applicability must be a ScriptBlock or null.")
        }

        $HostMinimum = $ExecutionMetadata.MinimumAnalysisHostVersion
        if ($null -ne $HostMinimum -and (
            $HostMinimum -isnot [version] -or $HostMinimum.Major -lt 1 -or
            $HostMinimum.Minor -lt 0 -or $HostMinimum.Build -ne -1 -or
            $HostMinimum.Revision -ne -1
        )) {
            throw [ArgumentException]::new(
                "Rule '$($this.Id)' MinimumAnalysisHostVersion must be a positive major/minor System.Version or null."
            )
        }
        $this.Applicability = $ExecutionMetadata.Applicability
        $this.MinimumAnalysisHostVersion = $HostMinimum
        $this.Settings = ConvertTo-NitpickRuleSettingsSchema `
            -Settings $ExecutionMetadata.Settings `
            -RuleId $this.Id `
            -ErrorAction Stop
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
        Producers receive recursively isolated plain-data context, with normalized
        policy, submitted-target identity, and actual analysis-host metadata.
    .PARAMETER Ast
        The ScriptBlockAst to check against the rule.
    .OUTPUTS
        [object[]] # NitpickFinding or DiagnosticRecord instances
    #>
    [object[]] Invoke([ScriptBlockAst] $Ast) {
        $Target = if ($this.DispatchType.Name -eq 'AstDocument') {
            New-AstDocument -InputObject $Ast
        } else {
            $Ast
        }

        $Parameters = @{
            Context = @{
                Caller = 'Nitpick'
                File = $Ast.Extent.File
                RuleBehavior = @{
                    SearchNestedScriptBlocks = $true
                    OutputType = 'NitpickFinding'
                }
            }
        }
        $Parameters[$this.DispatchParameterName] = $Target

        return $this.Invoke($Parameters)
    }

    <#
    .SYNOPSIS
        Invokes the rule against the specified ScriptBlockAst.
    .PARAMETER Ast
        The ScriptBlockAst to check against the rule.
    .PARAMETER Context
        Plain-data context to copy for the rule invocation. Nested mutation and ETS
        additions do not affect caller input or subsequent invocations. Unsupported
        values and invalid reserved metadata terminate with NitpickInvalidContext.
    .OUTPUTS
        [object[]] # NitpickFinding or DiagnosticRecord instances
    #>
    [object[]] Invoke(
        [ScriptBlockAst] $Ast,
        [IDictionary] $Context
    ) {
        $Target = if ($this.DispatchType.Name -eq 'AstDocument') {
            New-AstDocument -InputObject $Ast
        } else {
            $Ast
        }

        $Parameters = @{ Context = $Context }
        $Parameters[$this.DispatchParameterName] = $Target

        return $this.Invoke($Parameters)
    }

    <#
    .SYNOPSIS
        Invokes the rule against an AstDocument or its selected AST.
    .PARAMETER Document
        The document to dispatch to document rules or whose AST is dispatched to
        root-AST rules.
    .OUTPUTS
        [object[]] # NitpickFinding or DiagnosticRecord instances
    #>
    [object[]] Invoke([object] $Document) {
        if ($null -eq $Document -or $Document.GetType().Name -ne 'AstDocument') {
            throw [ArgumentException]::new('Rule invocation requires an AstDocument.')
        }

        return $this.Invoke($Document, @{
            Caller = 'Nitpick'
            File = $Document.Ast.Extent.File
            RuleBehavior = @{
                SearchNestedScriptBlocks = $true
                OutputType = 'NitpickFinding'
            }
        })
    }

    [object[]] Invoke(
        [object] $Document,
        [IDictionary] $Context
    ) {
        if ($null -eq $Document -or $Document.GetType().Name -ne 'AstDocument') {
            throw [ArgumentException]::new('Rule invocation requires an AstDocument.')
        }
        $Parameters = @{ Context = $Context }
        $Parameters[$this.DispatchParameterName] = $Document
        return $this.Invoke($Parameters)
    }

    <#
    .SYNOPSIS
        Invokes the rule against the specified parameters dictionary.
    .PARAMETER Parameters
        The parameters dictionary to pass to the rule invocation. Context is
        validated and recursively copied without mutating the supplied dictionary.
    .OUTPUTS
        [object[]] # NitpickFinding or DiagnosticRecord instances
    #>
    [object[]] Invoke(
        [IDictionary] $Parameters
    ) {
        return $this.InvokeWithResult($Parameters).Results
    }

    <#
    .SYNOPSIS
        Dispatches a document or AST and returns execution status and producer results.
    .DESCRIPTION
        Applicability is evaluated once with an isolated context before host
        prerequisites. The producer receives a different isolated copy.
    .EXAMPLE
        $Outcome = $Rule.InvokeWithResult($Document, @{})
        $Outcome.Status
        $Outcome.Results

        Distinguishes Inapplicable from Executed, including an empty execution.
    #>
    [NitpickRuleInvocationResult] InvokeWithResult(
        [object] $Document,
        [IDictionary] $Context
    ) {
        $Parameters = @{ Context = $Context }
        $Parameters[$this.DispatchParameterName] = $Document
        return $this.InvokeWithResult($Parameters)
    }

    <#
    .SYNOPSIS
        Validates and dispatches rule parameters through the shared execution gates.
    .DESCRIPTION
        Returns Inapplicable only for one Boolean false predicate result.
        Predicate failures, invalid output, and unmet host prerequisites terminate
        with rule-specific error records. Existing Invoke methods unwrap Results.
    .EXAMPLE
        $Outcome = $Rule.InvokeWithResult(@{ ScriptBlockAst = { Get-Process }.Ast })

        Uses the legacy AST parameter fallback and default invocation context.
    #>
    [NitpickRuleInvocationResult] InvokeWithResult(
        [IDictionary] $Parameters
    ) {
        $InvocationParameters = @{}
        foreach ($Key in $Parameters.Keys) {
            $InvocationParameters[$Key] = $Parameters[$Key]
        }

        $Target = $InvocationParameters[$this.DispatchParameterName]
        if ($null -eq $Target -and $InvocationParameters.Contains('ScriptBlockAst')) {
            $Target = $InvocationParameters.ScriptBlockAst
            $InvocationParameters.Remove('ScriptBlockAst')
        }

        $ContextTarget = $Target
        $CoordinatorDispatch = $InvocationParameters['__NitpickCoordinatorDispatch']
        if ($InvocationParameters.ContainsKey('__NitpickCoordinatorDispatch')) {
            $InvocationParameters.Remove('__NitpickCoordinatorDispatch')

            if (-not (Test-NitpickCoordinatorDispatch -Dispatch $CoordinatorDispatch)) {
                throw [ArgumentException]::new(
                    'Invalid coordinator-owned rule invocation context.'
                )
            }

            $ContextTarget = $CoordinatorDispatch.Target
        }

        if ($this.DispatchType.Name -eq 'AstDocument') {
            if ($Target -is [ScriptBlockAst]) {
                $Target = New-AstDocument -InputObject $Target
            } elseif ($null -eq $Target -or $Target.GetType().Name -ne 'AstDocument') {
                throw [ArgumentException]::new('Rule invocation requires an AstDocument.')
            }
        } else {
            if ($null -ne $Target -and $Target.GetType().Name -eq 'AstDocument') {
                $Target = $Target.Ast
            } elseif ($Target -isnot [ScriptBlockAst]) {
                throw [ArgumentException]::new('Rule invocation requires a ScriptBlockAst.')
            }
        }

        $Context = New-NitpickInvocationContext `
            -Target $ContextTarget `
            -Context $InvocationParameters.Context
        $SettingsInput = if ($Context.ContainsKey('RuleSettings')) {
            $Context.RuleSettings
        } else {
            @{}
        }
        $Context.RuleSettings = ConvertTo-NitpickEffectiveRuleSettings `
            -Schema $this.Settings `
            -Values $SettingsInput `
            -RuleId $this.Id `
            -ErrorAction Stop

        if ($null -ne $this.Applicability) {
            $IsApplicable = Test-NitpickRuleApplicability `
                -Applicability $this.Applicability `
                -Context (Copy-NitpickContextValue -Value $Context) `
                -RuleId $this.Id

            if (-not $IsApplicable) {
                return [NitpickRuleInvocationResult]::new('Inapplicable', @())
            }
        }

        $HostVersion = $Context.AnalysisHost.PowerShellVersion

        if ($null -ne $this.MinimumAnalysisHostVersion -and
            $HostVersion -lt $this.MinimumAnalysisHostVersion) {
            throw [ErrorRecord]::new(
                [InvalidOperationException]::new(
                    "Rule '$($this.Id)' requires analysis host PowerShell $($this.MinimumAnalysisHostVersion); actual host is $HostVersion."
                ),
                'NitpickUnsupportedAnalysisHost',
                [ErrorCategory]::NotImplemented,
                $this.Id
            )
        }

        $InvocationParameters[$this.DispatchParameterName] = $Target
        if (Get-CallableParameter -Callable $this.Callable -Name Context) {
            $InvocationParameters.Context = Copy-NitpickContextValue -Value $Context
        } else {
            $InvocationParameters.Remove('Context')
        }

        [object[]] $Results = @(& $this.Callable @InvocationParameters)
        foreach ($Finding in $Results) {
            if ($Finding -isnot [NitpickFinding]) {
                continue
            }

            $Finding.RuleId = $this.Id

            foreach ($Correction in $Finding.Corrections) {
                $Correction.RuleId = $this.Id
            }
        }
        return [NitpickRuleInvocationResult]::new('Executed', $Results)
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
            throw [ArgumentException]::new("Node '$Node' does not exist.")
        }

        return [string[]] $this.Edges[$Node]
    }

    [void] AddEdge([string] $From, [string] $To) {
        if ($this.Nodes -notcontains $From) {
            throw [ArgumentException]::new("Node '$From' does not exist.")
        }
        if ($this.Nodes -notcontains $To) {
            throw [ArgumentException]::new("Node '$To' does not exist.")
        }
        if ($this.Edges[$From] -contains $To) {
            return
        }
        if ($From -eq $To -or $this.IsReachable($To, $From)) {
            throw [InvalidOperationException]::new(
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
            return [Parser]::ParseInput($Input, [ref] $null, [ref] $null)
        }
        return $Input
    }
}

class NitpickCorrectionProposal {
    [string] $Path = '<ScriptBlock>'
    # Origin file when the snapshot has source provenance; informational only, never a write target.
    [string] $SourcePath
    [psobject] $Document
    [string] $OriginalFingerprint
    [string] $Status = 'NoChanges'
    [string] $OriginalText
    [string] $OriginalFragmentText
    [NitpickFinding[]] $OriginalFindings = @()
    [string] $CandidateText
    [string] $CandidateFragmentText
    [NitpickFinding[]] $CandidateFindings = @()
    [NitpickFinding[]] $UndecidedFindings = @()
    [NitpickFinding[]] $SkippedFindings = @()
    [bool] $WasReanalyzed
    [NitpickCorrection[]] $AcceptedCorrections = @()
    [object[]] $SkippedCorrections = @()
    [object[]] $Conflicts = @()
    [object[]] $ParseErrors = @()
    [string] $Diff
}

class NitpickCorrectionApplication {
    [string] $Status = 'NotAttempted'
    [NitpickCorrection[]] $AppliedCorrections = @()
    [psobject] $WriteResult
    [ErrorRecord] $ErrorRecord
}

class NitpickCorrectionReport {
    [string] $AnalysisSource = 'None'
    [string] $EffectiveText
    [NitpickFinding[]] $EffectiveFindings = @()
    [NitpickFinding[]] $FindingsWithAppliedCorrections = @()
    [NitpickFinding[]] $FindingsWithAcceptedCorrections = @()
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


# MARK: EXPORTS
#
# Prevent `Should-Process` from triggering invalid verb warning because
# `Import-Module` uses everything by default if `Export-ModuleMember` is
# not specified even if the manifest gets applied afterwards. Don't feel
# like aliasing `Should-Process` to avoid the invalid verb warning.
#
# Powershell module loading is so unnecessarily bad...
$ManifestPath = Join-Path -Path $ModuleRoot -ChildPath 'Nitpick.psd1'
if (-not (Test-Path -Path $ManifestPath)) {
    throw "Module manifest not found at '$ManifestPath'."
}

try {
    $Manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath -ErrorAction Stop
} catch {
    throw "Failed to load module manifest '$ManifestPath'. Error: $_"
}

$ExportParams = @{}
if ($Manifest.FunctionsToExport.Count -gt 0) {
    $ExportParams.Function = $Manifest.FunctionsToExport
}
if ($Manifest.CmdletsToExport.Count -gt 0) {
    $ExportParams.Cmdlet = $Manifest.CmdletsToExport
}
if ($Manifest.VariablesToExport.Count -gt 0) {
    $ExportParams.Variable = $Manifest.VariablesToExport
}
if ($Manifest.AliasesToExport.Count -gt 0) {
    $ExportParams.Alias = $Manifest.AliasesToExport
}

Export-ModuleMember @ExportParams
