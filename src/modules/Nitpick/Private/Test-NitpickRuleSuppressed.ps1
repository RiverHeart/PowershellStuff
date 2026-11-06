<#
.SYNOPSIS
    Matches whole-target selectors without suppressing coordinator diagnostics.
#>
function Test-NitpickRuleSuppressed {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string] $RuleId,

        [Parameter(Mandatory)]
        [psobject] $Suppression
    )

    if ($RuleId -in 'Nitpick/PowerShellParseError', 'Nitpick/InvalidSuppressionDirective') {
        return $false
    }

    foreach ($Selector in $Suppression.Selectors) {
        if ($RuleId -like $Selector) {
            return $true
        }
    }

    return $false
}
