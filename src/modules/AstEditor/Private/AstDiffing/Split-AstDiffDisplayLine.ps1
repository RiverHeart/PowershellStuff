<#
.SYNOPSIS
    Splits diff text into display lines, omitting its final line terminator.
#>
function Split-AstDiffDisplayLine {
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    if ($Value.Length -eq 0) {
        return , @()
    }

    $LineTerminatorPattern = '\r\n|\n|\r'
    $Trimmed = $Value -replace "(?:$LineTerminatorPattern)\z", ''
    return , ($Trimmed -split $LineTerminatorPattern)
}
