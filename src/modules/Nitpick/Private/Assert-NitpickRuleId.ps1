<#
.SYNOPSIS
    Validates that a given Nitpick RuleId has the correct format.

.DESCRIPTION
    The Assert-NitpickRuleId function checks that the provided RuleId follows the expected 'Namespace/Name' format.
    It also validates each segment using the Assert-NitpickIdentitySegment function.

.PARAMETER Value
    The RuleId to validate. Must be a string in the form 'Namespace/Name'.

.EXAMPLE
    Validate that 'MyNamespace/MyRule' is a correctly formatted Nitpick RuleId.

    Assert-NitpickRuleId -Value 'MyNamespace/MyRule'
#>
function Assert-NitpickRuleId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    $Segments = $Value.Split('/')
    if ($Segments.Count -ne 2) {
        throw "Nitpick RuleId '$Value' must have the form Namespace/Name."
    }

    Assert-NitpickIdentitySegment -Value $Segments[0] -SegmentType Namespace
    Assert-NitpickIdentitySegment -Value $Segments[1] -SegmentType Name
}
