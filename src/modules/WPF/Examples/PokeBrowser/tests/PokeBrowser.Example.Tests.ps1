using module ../PokeBrowser.Models.psm1

Describe 'PokeBrowser example' -Tag 'PokeBrowser-Example' {
    BeforeAll {
        . "$PSScriptRoot/../functions/Get-PokeBrowserCatalog.ps1"
        . "$PSScriptRoot/../functions/Get-PokeBrowserCachedCatalog.ps1"
        . "$PSScriptRoot/../functions/Get-PokeBrowserDetail.ps1"
    }

    It 'Builds typed domain models from a mocked catalog response' {
        Mock Invoke-RestMethod {
            [pscustomobject] @{
                results = @(
                    [pscustomobject] @{ name = 'pikachu'; url = 'https://pokeapi.co/api/v2/pokemon/25/' }
                    [pscustomobject] @{ name = 'bulbasaur'; url = 'https://pokeapi.co/api/v2/pokemon/1/' }
                )
            }
        }

        $catalog = @(Get-PokeBrowserCatalog -Limit 2)

        $catalog.Count | Should -Be 2
        $catalog[0] | Should -BeOfType ([PokemonSummary])
        $catalog[0].Name | Should -Be 'Bulbasaur'
        $catalog[0].ResourceUri.AbsoluteUri | Should -Be 'https://pokeapi.co/api/v2/pokemon/1/'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri.AbsoluteUri -eq 'https://pokeapi.co/api/v2/pokemon?limit=2'
        }
    }

    It 'Writes refreshed catalog data to a JSON cache' {
        $Storage = New-WPFAppStorage `
            -Application 'PokeBrowserWriteTest' `
            -Publisher 'TestPublisher' `
            -RootPath $TestDrive

        Mock Get-PokeBrowserCatalog {
            [PokemonSummary[]] @(
                [PokemonSummary]::new('Bulbasaur', 'https://pokeapi.co/api/v2/pokemon/1/')
                [PokemonSummary]::new('Pikachu', 'https://pokeapi.co/api/v2/pokemon/25/')
            )
        }

        $Catalog = Get-PokeBrowserCachedCatalog -Storage $Storage -Refresh
        $CachedCatalog = @(Get-WPFStoredItem -Storage $Storage -Name 'Catalog')

        $Catalog.GetType() | Should -Be ([PokemonSummary[]])
        $Catalog[0] | Should -BeOfType ([PokemonSummary])
        $CachedCatalog[0].Name | Should -Be 'Bulbasaur'
        $CachedCatalog[0].ResourceUri | Should -Be 'https://pokeapi.co/api/v2/pokemon/1/'
    }

    It 'Rehydrates typed catalog data from the JSON cache' {
        $Storage = New-WPFAppStorage `
            -Application 'PokeBrowserReadTest' `
            -Publisher 'TestPublisher' `
            -RootPath $TestDrive

        $CachedCatalog = @(
            [pscustomobject] @{
                Name = 'Bulbasaur'
                ResourceUri = 'https://pokeapi.co/api/v2/pokemon/1/'
            }
        )

        Set-WPFStoredItem -Storage $Storage -Name 'Catalog' -Value $CachedCatalog
        Mock Get-PokeBrowserCatalog { throw 'The API should not be called.' }

        $Catalog = Get-PokeBrowserCachedCatalog -Storage $Storage

        $Catalog.GetType() | Should -Be ([PokemonSummary[]])
        $Catalog[0] | Should -BeOfType ([PokemonSummary])
        $Catalog[0].ResourceUri.AbsoluteUri | Should -Be 'https://pokeapi.co/api/v2/pokemon/1/'
        Should -Invoke Get-PokeBrowserCatalog -Times 0 -Exactly
    }

    It 'Builds a typed detail model from a mocked Pokemon response' {
        Mock Invoke-RestMethod {
            [pscustomobject] @{
                name = 'bulbasaur'
                height = 7
                weight = 69
                types = @(
                    [pscustomobject] @{ slot = 2; type = [pscustomobject] @{ name = 'poison' } }
                    [pscustomobject] @{ slot = 1; type = [pscustomobject] @{ name = 'grass' } }
                )
                sprites = [pscustomobject] @{
                    front_default = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/1.png'
                }
            }
        }

        $Pokemon = [PokemonSummary]::new('Bulbasaur', 'https://pokeapi.co/api/v2/pokemon/1/')
        $detail = Get-PokeBrowserDetail -Pokemon $Pokemon

        $detail | Should -BeOfType ([PokemonDetail])
        $detail.Name | Should -Be 'Bulbasaur'
        $detail.Height | Should -Be 7
        $detail.Weight | Should -Be 69
        $detail.Type | Should -Be 'Grass / Poison'
        $detail.ImageUri.AbsoluteUri | Should -Match '/sprites/pokemon/1\.png$'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri.AbsoluteUri -eq 'https://pokeapi.co/api/v2/pokemon/1/'
        }
    }

    It 'Propagates network failures to the caller' {
        Mock Invoke-RestMethod { throw 'PokeAPI unavailable' }

        { Get-PokeBrowserCatalog } | Should -Throw '*PokeAPI unavailable*'
    }

    It 'Provides a neutral detail model for initial bindings' {
        $detail = [PokemonDetail]::new('', 0, 0, '', $null)

        $detail.Name | Should -BeNullOrEmpty
        $detail.Type | Should -BeNullOrEmpty
        $detail.ImageUri | Should -Be $null
    }
}
