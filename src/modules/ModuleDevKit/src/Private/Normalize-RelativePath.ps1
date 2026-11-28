<#
.SYNOPSIS
    Normalizes a relative file path by removing leading './' and converting '/' to '\'.

.EXAMPLE
    Basic usage

    $normalizedPath = Normalize-RelativePath -Path "./folder/file.txt"
#>
function Normalize-RelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    return ($Path -replace '^\./', '') -replace '/', '\\'
}
