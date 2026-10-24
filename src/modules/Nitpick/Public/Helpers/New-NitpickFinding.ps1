<#
.SYNOPSIS
    Creates a new Nitpick finding object.

.DESCRIPTION
    Creates a new Nitpick finding object with the specified properties. When OutputAs is not
    specified, native Nitpick rule invocations return NitpickFinding objects and direct rule
    invocations from PSScriptAnalyzer return DiagnosticRecord objects.
    Diagnostic conversion omits corrections with a ChangeSetId because ScriptAnalyzer
    cannot preserve their all-or-nothing selection. Ungrouped suggestions remain available.

.EXAMPLE
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
    [OutputType([object])]
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
        [string] $OutputAs
    )

    if (-not $PSBoundParameters.ContainsKey('OutputAs')) {
        # Must match NitpickRule.Invoke()'s global (not script) scope; see its comment.
        $OutputAs = if ($global:NitpickInvocationContext -eq 'Nitpick') {
            'NitpickFinding'
        } elseif (Test-AssemblyLoaded -Name 'Microsoft.Windows.PowerShell.ScriptAnalyzer') {
            'DiagnosticRecord'
        } else {
            'NitpickFinding'
        }
    }

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
