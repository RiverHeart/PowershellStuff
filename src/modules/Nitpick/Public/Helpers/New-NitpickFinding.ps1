<#
.SYNOPSIS
    Creates a new Nitpick finding object.

.DESCRIPTION
    Creates a new Nitpick finding object with the specified properties.

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
        [NitpickCorrection[]] $Corrections,

        [Parameter(ParameterSetName='ByLineAndColumn', HelpMessage = "Specifies the output format for the Finding extent.")]
        [Parameter(ParameterSetName='ByExtent', HelpMessage = "Specifies the output format for the Finding extent.")]
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
        Corrections = $Corrections
    }
    $Finding = [NitpickFinding]::new($FindingParams)

    if ($OutputAs -eq 'DiagnosticRecord') {
        $Finding = $Finding.ToDiagnosticRecord()
    }

    return $Finding
}
