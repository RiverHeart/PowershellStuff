<#
.SYNOPSIS
    Updates the Pokemon catalog in the PokeBrowser window.
#>
function Update-PokeBrowserCatalog {
    param (
        [string] $ContextId,

        [switch] $Refresh
    )

    $Window = Get-WPFWindow -ContextId $ContextId -ErrorAction Stop
    if (-not $ContextId) {
        $ContextId = Get-WPFContextId -InputObject $Window -ErrorAction Stop
    }
    $State = $Window.DataContext
    if (-not $State) {
        Write-Warning "Unable to retrieve state from window with ContextId '$ContextId'."
        return
    }

    try {
        $Catalog = Get-PokeBrowserCachedCatalog `
            -Refresh:$Refresh `
            -Storage $State.Storage `
            -ErrorAction Stop

        $State.PokemonList.Clear()
        foreach ($Pokemon in $Catalog) {
            $State.PokemonList.Add($Pokemon)
        }

        $State.StatusText = "Loaded $($Catalog.Count) Pokemon from PokeAPI"
    } catch {
        $State.StatusText = "Unable to load Pokemon catalog: $($_.Exception.Message)"
    } finally {
        $State.IsLoading = $false
        NotifyCanExecuteChanged 'RefreshCatalogButton'
    }
}
