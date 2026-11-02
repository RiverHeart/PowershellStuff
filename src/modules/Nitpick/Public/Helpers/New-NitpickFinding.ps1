<#
.SYNOPSIS
    Creates a new Nitpick finding object.

.DESCRIPTION
    Creates a new Nitpick finding object with the specified properties. When OutputAs is not
    specified, returns NitpickFinding regardless of which assemblies are loaded.
    ScriptAnalyzer-compatible rules must explicitly request DiagnosticRecord output.
    Diagnostic conversion omits corrections with a ChangeSetId because ScriptAnalyzer
    cannot preserve their all-or-nothing selection. Ungrouped suggestions remain available.
    Standalone callers can supply a qualified RuleId instead of the legacy RuleName and
    RuleSuppressionID parameters. Its local name populates both compatibility fields.
    Legacy calls retain their supplied labels without inventing a qualified identity.
    NitpickRule.Invoke replaces producer-supplied identity on native findings and nested
    corrections with the executing descriptor's identity.

.PARAMETER RuleId
    Explicit standalone identity in Namespace/Name form, without wildcard syntax.
    Mutually exclusive with RuleName and RuleSuppressionID. It does not infer or assign
    identity to nested corrections; supply their RuleId separately when needed.

.EXAMPLE
    Creates a new Nitpick finding object with the specified properties.

    $Finding = New-NitpickFinding `
        -RuleId 'Local/MyRule' `
        -Message 'This is a test message' `
        -ViolationExtent $extent `
        -Severity 'Warning' `
        -ScriptPath '<ScriptBlock>' `
        -Explanation 'Why this rule applies.' `
        -Corrections @() `
        -OutputAs 'NitpickFinding'
#>
function New-NitpickFinding {
    [CmdletBinding(DefaultParameterSetName = 'Legacy')]
    [OutputType('NitpickFinding')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Legacy')]
        [string] $RuleName,

        [Parameter(Mandatory)]
        [string] $Message,

        [Parameter(Mandatory)]
        [System.Management.Automation.Language.IScriptExtent] $ViolationExtent,

        [Parameter(Mandatory)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string] $Severity,

        [Parameter(Mandatory, ParameterSetName = 'Legacy')]
        [string] $RuleSuppressionID,

        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $Explanation,

        [NitpickCorrection[]] $Corrections,

        [Parameter(HelpMessage = "Determines whether the rule should be executed based on this condition.")]
        [scriptblock] $RunCondition,

        [Parameter(HelpMessage = "Specifies the output format for the finding.")]
        [ValidateSet('NitpickFinding', 'DiagnosticRecord')]
        [string] $OutputAs = 'NitpickFinding',

        [Parameter(Mandatory, ParameterSetName = 'ByRuleId')]
        [ValidateNotNullOrEmpty()]
        [string] $RuleId
    )

    $Finding = $null
    $FindingParams = @{
        ViolationExtent = $ViolationExtent
        Message = $Message
        Severity = $Severity
        ScriptPath = $ScriptPath
        Explanation = $Explanation
    }
    if ($PSCmdlet.ParameterSetName -eq 'ByRuleId') {
        $FindingParams.RuleId = $RuleId
    } else {
        $FindingParams.RuleName = $RuleName
        $FindingParams.RuleSuppressionID = $RuleSuppressionID
    }
    if ($Corrections) { $FindingParams.Corrections = $Corrections }
    if ($RunCondition) { $FindingParams.RunCondition = $RunCondition }

    $Finding = [NitpickFinding]::new($FindingParams)

    if ($OutputAs -eq 'DiagnosticRecord') {
        $Finding = $Finding.ToDiagnosticRecord()
    }

    return $Finding
}
