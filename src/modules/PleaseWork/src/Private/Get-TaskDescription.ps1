<#
.SYNOPSIS
    Converts task declaration comments into description text.
#>
function Get-TaskDescription {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Comments
    )

    $DescriptionParts = foreach ($Comment in $Comments) {
        if ($Comment.StartsWith('<#') -and $Comment.EndsWith('#>')) {
            $Comment.Substring(2, $Comment.Length - 4).Trim()
        } else {
            ($Comment -replace '^# ?', '').TrimEnd()
        }
    }

    return ($DescriptionParts -join [Environment]::NewLine).Trim()
}
