<#
.SYNOPSIS
    Determines whether a module reference should be treated as a literal filesystem path.

.DESCRIPTION
    Recognizes path separators, provider-qualified syntax, recognized module file
    extensions, and bare values that already exist as a filesystem entry relative
    to the current location. A value that looks path-shaped must be resolved as a
    literal path and must never fall back to name-based module resolution.

.EXAMPLE
    Test-NitpickModulePathShape -Value '.\WPF\WPF.psd1'

.EXAMPLE
    Test-NitpickModulePathShape -Value 'WPF'
#>
function Test-NitpickModulePathShape {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    if ($Value.Contains('::')) {
        return $true
    }

    if ($Value.IndexOfAny([char[]] @('\', '/')) -ge 0) {
        return $true
    }

    $RecognizedExtensions = '.psd1', '.psm1', '.dll'
    if ($RecognizedExtensions -contains [System.IO.Path]::GetExtension($Value)) {
        return $true
    }

    try {
        return (Test-Path -LiteralPath $Value)
    } catch {
        return $false
    }
}
