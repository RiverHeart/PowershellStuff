<#
.SYNOPSIS
    Matches target selectors and optional finding start-line selectors.
#>
function Test-NitpickRuleSuppressed {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string] $RuleId,

        [Parameter(Mandatory)]
        [psobject] $Suppression,

        [int] $StartLineNumber
    )

    if ($RuleId -in 'Nitpick/PowerShellParseError', 'Nitpick/InvalidSuppressionDirective') {
        return $false
    }

    foreach ($Selector in $Suppression.Selectors) {
        if ($RuleId -like $Selector) {
            return $true
        }
    }

    if ($PSBoundParameters.ContainsKey('StartLineNumber')) {
        foreach ($Selector in $Suppression.LineSelectors[$StartLineNumber]) {
            if ($RuleId -like $Selector) {
                return $true
            }
        }
    }

    return $false
}
