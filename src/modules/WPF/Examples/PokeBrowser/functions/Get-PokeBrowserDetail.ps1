using module ../PokeBrowser.Models.psm1

<#
.SYNOPSIS
    Retrieves detailed information for a Pokemon from PokeAPI.

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
