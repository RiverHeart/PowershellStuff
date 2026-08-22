using module ../PokeBrowser.Models.psm1

<#
.SYNOPSIS
    Retrieves Pokemon summaries from PokeAPI.

.NOTES
    MIT License

    Copyright (c) 2019 Jakub Jareš

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

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
    $Response = Invoke-RestMethod -Uri $UriBuilder.Uri -Method Get -ErrorAction Stop
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
