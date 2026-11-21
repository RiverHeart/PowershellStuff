<#
.SYNOPSIS
    Determines whether a module reference should be treated as a literal filesystem path.

.DESCRIPTION
    Recognizes path separators, provider-qualified syntax, recognized module file
    extensions, and bare values that already exist as a filesystem entry relative
    to the current location. A value that looks path-shaped must be resolved as a
    literal path and must never fall back to name-based module resolution.

.PARAMETER Value
    The module name or path to test.

.PARAMETER SyntaxOnly
    Skips the check for an existing filesystem entry, so the result depends only
    on how Value is written and not on the current location. Configuration files
    use this so their entries mean the same thing wherever a command is run.

.EXAMPLE
    Test-NitpickModulePathShape -Value '.\WPF\WPF.psd1'

.EXAMPLE
    Test-NitpickModulePathShape -Value 'WPF' -SyntaxOnly

    Returns False, even when a WPF directory exists in the current location.
#>
function Test-NitpickModulePathShape {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value,

        [switch] $SyntaxOnly
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

    if ($SyntaxOnly) {
        return $false
    }

    try {
        return (Test-Path -LiteralPath $Value)
    } catch {
        return $false
    }
}
