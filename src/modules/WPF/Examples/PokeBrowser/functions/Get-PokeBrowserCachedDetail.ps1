<#
.SYNOPSIS
    Retrieves the cached detail of a Pokémon from application storage.
#>
function Get-PokeBrowserCachedDetail {
    [CmdletBinding()]
    [OutputType([PokemonDetail])]
    param (
        [Parameter(Mandatory)]
        [PSTypeName('WPF.ApplicationStorage')]
        $Storage,

        [Parameter(Mandatory)]
        [PokemonSummary] $Pokemon
    )

    $CachedDetail = Get-WPFStoredItem -Storage $Storage -Name "PokemonDetail_$($Pokemon.Name)"
    if ($null -ne $CachedDetail) {
        Write-Debug "Cache hit for Pokemon '$($Pokemon.Name)'. Returning cached detail."
        $Detail = [PokemonDetail]::FromObject($CachedDetail)
        return $Detail
    }

    Write-Verbose "No cached detail found for Pokemon '$($Pokemon.Name)'. Retrieving from PokeAPI."
    $Detail = Get-PokeBrowserDetail -Pokemon $Pokemon
    if ($null -ne $Detail) {
        Set-WPFStoredItem `
            -Storage $Storage `
            -Name "PokemonDetail_$($Pokemon.Name)" `
            -Value $Detail
    }
    return $Detail
}
