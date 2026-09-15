<#
.SYNOPSIS
    Compares two script block ASTs by their top-level statement text.

.DESCRIPTION
    Returns $true only when both script blocks contain the same number of
    statements and each statement has identical trimmed text in order.
#>
function Test-ScriptBlockStatementTextEquivalent {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [ScriptBlockAst] $Left,

        [Parameter(Mandatory)]
        [ScriptBlockAst] $Right
    )

    $LeftStatementText = Get-ScriptBlockStatementText -ScriptBlockAst $Left
    $RightStatementText = Get-ScriptBlockStatementText -ScriptBlockAst $Right

    if ($LeftStatementText.Count -ne $RightStatementText.Count) {
        return $false
    }

    for ($Index = 0; $Index -lt $LeftStatementText.Count; $Index++) {
        if ($LeftStatementText[$Index] -ne $RightStatementText[$Index]) {
            return $false
        }
    }

    return $true
}