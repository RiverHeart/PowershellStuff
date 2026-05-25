<#
.SYNOPSIS
    Returns the module-level Chrome adapter registry.

.DESCRIPTION
    Provides access to the internal Chrome adapter registry used by Chrome and
    registration helpers.

    When -InitializeDefaults is specified and the registry is empty, defaults
    are seeded from Get-WPFDefaultChromeAdapterCatalog. This explicit catalog
    acts as an allow list so helper files in Private/ChromeAdapters are not
    automatically registered unless intentionally included.

    Note that adapter factory functions in Private are internal implementation
    details and are not public module exports.
#>
function Get-WPFChromeAdapterRegistry {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [switch] $InitializeDefaults
    )

    if (-not $script:WPFChromeAdapterRegistry) {
        $script:WPFChromeAdapterRegistry = [ordered] @{}
    }

    if ($InitializeDefaults -and $script:WPFChromeAdapterRegistry.Count -eq 0) {
        foreach ($adapter in @(Get-WPFDefaultChromeAdapterCatalog)) {
            if ($null -eq $adapter) {
                continue
            }

            if ($adapter.TargetType -isnot [type]) {
                Write-Warning 'Get-WPFChromeAdapterRegistry: Skipping a default Chrome adapter with an invalid TargetType.'
                continue
            }

            $adapterKey = $adapter.TargetType.AssemblyQualifiedName
            if ([string]::IsNullOrWhiteSpace($adapterKey)) {
                Write-Warning "Get-WPFChromeAdapterRegistry: Skipping default adapter '$($adapter.Name)' because TargetType did not provide a key."
                continue
            }

            $script:WPFChromeAdapterRegistry[$adapterKey] = $adapter
        }
    }

    return $script:WPFChromeAdapterRegistry
}
