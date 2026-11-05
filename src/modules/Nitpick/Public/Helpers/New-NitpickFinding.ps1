<#
.SYNOPSIS
    Creates a new Nitpick finding object.

.DESCRIPTION
    Creates a new Nitpick finding object with the specified properties. When OutputAs is not
    specified, returns NitpickFinding regardless of which assemblies are loaded.
    ScriptAnalyzer-compatible rules must explicitly request DiagnosticRecord output.
    Diagnostic conversion omits multi-edit corrections because ScriptAnalyzer
    cannot preserve their all-or-nothing application. Single-edit corrections remain available.
    Findings require a qualified RuleId. Diagnostic conversion derives local RuleName
    and RuleSuppressionID values at the external boundary; native objects carry only RuleId.
    NitpickRule.Invoke replaces producer-supplied identity on native findings and nested
    corrections with the executing descriptor's identity.

.PARAMETER RuleId
    Required identity in Namespace/Name form, without wildcard syntax.
    It does not infer or assign
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
    [CmdletBinding()]
    [OutputType('NitpickFinding')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RuleId,

        [Parameter(Mandatory)]
        [string] $Message,

        [Parameter(Mandatory)]
        [System.Management.Automation.Language.IScriptExtent] $ViolationExtent,

        [Parameter(Mandatory)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string] $Severity,

        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $Explanation,

        [NitpickCorrection[]] $Corrections,

        [Parameter(HelpMessage = "Determines whether the rule should be executed based on this condition.")]
        [scriptblock] $RunCondition,

        [Parameter(HelpMessage = "Specifies the output format for the finding.")]
        [ValidateSet('NitpickFinding', 'DiagnosticRecord')]
        [string] $OutputAs = 'NitpickFinding'
    )

    $Finding = $null
    $FindingParams = @{
        ViolationExtent = $ViolationExtent
        Message = $Message
        Severity = $Severity
        ScriptPath = $ScriptPath
        Explanation = $Explanation
        RuleId = $RuleId
    }
    if ($Corrections) { $FindingParams.Corrections = $Corrections }
    if ($RunCondition) { $FindingParams.RunCondition = $RunCondition }

    $Finding = [NitpickFinding]::new($FindingParams)

    if ($OutputAs -eq 'DiagnosticRecord') {
        $Finding = $Finding.ToDiagnosticRecord()
    }

    return $Finding
}
