<#
.SYNOPSIS
    Returns qualified native attribution, or a placeholder for unattributed corrections.
#>
function Get-NitpickRuleLabel {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [object] $InputObject
    )

    if ($InputObject.RuleId) {
        $InputObject.RuleId
    } else {
        'unattributed'
    }
}
