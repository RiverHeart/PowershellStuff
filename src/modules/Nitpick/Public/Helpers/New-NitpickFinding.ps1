<#
.SYNOPSIS
    Creates a new Nitpick finding object.

.DESCRIPTION
    Creates a new Nitpick finding object with the specified properties. When OutputAs is not
    specified, returns NitpickFinding regardless of which assemblies are loaded.
    ScriptAnalyzer-compatible rules must explicitly request DiagnosticRecord output.
    Diagnostic conversion omits corrections with a ChangeSetId because ScriptAnalyzer
    cannot preserve their all-or-nothing selection. Ungrouped suggestions remain available.
    Standalone findings retain producer-supplied local labels and have no qualified RuleId.
    NitpickRule. Invoke assigns descriptor-owned RuleId and RuleName to native findings
    and nested corrections, and assigns the same local name to findings' RuleSuppressionID.

.EXAMPLE
    Creates a new Nitpick finding object with the specified properties.

    $Finding = New-NitpickFinding `
        -RuleName 'MyRule' `
        -Message 'This is a test message' `
        -ViolationExtent $extent `
        -Severity 'Warning' `
        -RuleSuppressionID 'None' `
        -Corrections @() `
        -OutputAs 'NitpickFinding'
#>
function New-NitpickFinding {
    [CmdletBinding()]
    [OutputType('NitpickFinding')]
    param(
        [Parameter(Mandatory)]
        [string] $RuleName,

        [Parameter(Mandatory)]
        [string] $Message,

        [Parameter(Mandatory)]
        [System.Management.Automation.Language.IScriptExtent] $ViolationExtent,

        [Parameter(Mandatory)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string] $Severity,

        [Parameter(Mandatory)]
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
        [string] $OutputAs = 'NitpickFinding'
    )

    $Finding = $null
    $FindingParams = @{
        ViolationExtent = $ViolationExtent
        Message = $Message
        RuleName = $RuleName
        RuleSuppressionID = $RuleSuppressionID
        Severity = $Severity
        ScriptPath = $ScriptPath
        Explanation = $Explanation
    }
    if ($Corrections) { $FindingParams.Corrections = $Corrections }
    if ($RunCondition) { $FindingParams.RunCondition = $RunCondition }

    $Finding = [NitpickFinding]::new($FindingParams)

    if ($OutputAs -eq 'DiagnosticRecord') {
        $Finding = $Finding.ToDiagnosticRecord()
    }

    return $Finding
}
