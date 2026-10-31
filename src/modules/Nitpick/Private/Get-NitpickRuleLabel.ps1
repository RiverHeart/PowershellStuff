<#
.SYNOPSIS
    Selects qualified attribution or a standalone producer's unqualified display label.
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
        $InputObject.RuleName
    }
}
