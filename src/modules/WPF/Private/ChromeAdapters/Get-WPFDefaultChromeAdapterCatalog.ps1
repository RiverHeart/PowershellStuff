<#
.SYNOPSIS
    Returns module-provided default Chrome adapters.

.DESCRIPTION
    Defines the explicit set of built-in Chrome adapters used for default
    registry initialization.

    Keeping this as an explicit list prevents accidental default registration
    of adapter factories that happen to exist in Private/ChromeAdapters.
#>
function Get-WPFDefaultChromeAdapterCatalog {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    return @(
        New-WPFButtonChromeAdapter
    )
}
