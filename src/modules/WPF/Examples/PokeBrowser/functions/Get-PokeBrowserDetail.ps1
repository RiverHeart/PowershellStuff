using module ../PokeBrowser.Models.psm1

<#
.SYNOPSIS
    Retrieves detailed information for a Pokemon from PokeAPI.

.NOTES
    Adapted from Jakub Jareš' PokeBrowser.
    See THIRD-PARTY-NOTICES.txt for attribution and license terms.
#>
function Get-PokeBrowserDetail {
    [CmdletBinding()]
    [OutputType([PokemonDetail])]
    param (
        [Parameter(Mandatory)]
        [PokemonSummary] $Pokemon
    )

    $Response = Invoke-RestMethod -Uri $Pokemon.ResourceUri -Method Get -ErrorAction Stop
    $TextInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
    $Types = @(
        $Response.types |
            Sort-Object -Property slot |
            ForEach-Object { $TextInfo.ToTitleCase([string] $_.type.name) }
    )

    return [PokemonDetail]::new(
        $TextInfo.ToTitleCase([string] $Response.name),
        [int] $Response.height,
        [int] $Response.weight,
        ($Types -join ' / '),
        [uri] $Response.sprites.front_default
    )
}
