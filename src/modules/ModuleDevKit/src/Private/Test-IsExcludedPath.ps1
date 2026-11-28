<#
.SYNOPSIS
    Tests if a given path matches any of the excluded path regex patterns.

.EXAMPLE
    Basic usage

    $isExcluded = Test-IsExcludedPath `
        -Path "folder/file.txt" `
        -ExcludePathRegex "folder/.*"
#>
function Test-IsExcludedPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ExcludePathRegex
    )

    foreach ($pattern in $ExcludePathRegex) {
        if ($Path -match $pattern) {
            return $true
        }
    }

    return $false
}
