using module ../PokeBrowser.Models.psm1

<#
.SYNOPSIS
    Retrieves Pokemon summaries from PokeAPI.

.NOTES
    Adapted from Jakub Jareš' PokeBrowser.
    See THIRD-PARTY-NOTICES.txt for attribution and license terms.

.EXAMPLE
    Get a list of Pokemon summaries from PokeAPI.

    Get-PokeBrowserCatalog -Limit 10

.EXAMPLE
    Get a list of Pokemon summaries from PokeAPI and display their names.

    Get-PokeBrowserCatalog -Limit 10 | ForEach-Object { $_.Name }
#>
function Get-PokeBrowserCatalog {
    [CmdletBinding()]
    [OutputType([PokemonSummary[]])]
    param (
        [Parameter()]
        [ValidateRange(1, 1000)]
        [int] $Limit = 300
    )

    $UriBuilder = [System.UriBuilder]::new('https://pokeapi.co/api/v2/pokemon')
    $UriBuilder.Query = "limit=$Limit"
    $Response = Invoke-RestMethod -Uri $UriBuilder.Uri -Method Get -ErrorAction Stop -Debug:$false
    $TextInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo

    return [PokemonSummary[]] @(
        $Response.results |
            Sort-Object -Property name |
            ForEach-Object {
                [PokemonSummary]::new(
                    $TextInfo.ToTitleCase([string] $_.name),
                    [uri] $_.url
                )
            }
    )
}
