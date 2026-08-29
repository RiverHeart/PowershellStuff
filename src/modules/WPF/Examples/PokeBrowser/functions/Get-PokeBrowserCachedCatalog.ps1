
<#
.SYNOPSIS
    Retrieves the cached catalog of Pokémon from application storage.

.DESCRIPTION
    Retrieves the cached catalog of Pokémon from application storage.
    If the catalog is not cached or if the $Refresh switch is specified,
    the catalog is retrieved from the PokeAPI and stored in application storage.

.EXAMPLE
    Retrieve the cached catalog of Pokémon from application storage.

    $Storage = New-WPFAppStorage -Application 'PokeBrowser'
    $Catalog = Get-PokeBrowserCachedCatalog -Storage $Storage
#>
function Get-PokeBrowserCachedCatalog {
    [CmdletBinding()]
    [OutputType([PokemonSummary[]])]
    param (
        [Parameter(Mandatory)]
        [PSTypeName('WPF.ApplicationStorage')]
        $Storage,

        [switch] $Refresh
    )

    if ($Refresh) {
        Write-Verbose 'Refresh switch specified. Retrieving catalog from PokeAPI.'
    } else {
        $CachedCatalog = Get-WPFStoredItem -Storage $Storage -Name 'Catalog'
        if ($CachedCatalog) {
            Write-Verbose 'Cache hit for catalog. Returning cached catalog.'
            $Catalog = [PokemonSummary[]] @(
                $CachedCatalog | ForEach-Object {
                    [PokemonSummary]::FromObject($_)
                }
            )
            return ,$Catalog
        }
    }

    Write-Verbose 'No cached catalog found. Refreshing from PokeAPI.'
    $Catalog = [PokemonSummary[]] @(Get-PokeBrowserCatalog)
    Set-WPFStoredItem `
        -Storage $Storage `
        -Name 'Catalog' `
        -Value $Catalog

    return ,$Catalog
}
