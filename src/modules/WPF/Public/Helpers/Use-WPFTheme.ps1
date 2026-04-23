<#
.SYNOPSIS
    Applies a named WPF theme to a root element.

.DESCRIPTION
    Replaces the active theme dictionary in Root.Resources.MergedDictionaries
    with the dictionary registered by Theme.

.EXAMPLE
    Use-WPFTheme -Name Dark
#>
function Use-WPFTheme {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Position = 1)]
        [System.Windows.FrameworkElement] $Root = (Reference 'Window')
    )

    if (-not $script:WPFThemeTable -or -not $script:WPFThemeTable.ContainsKey($Name)) {
        Write-Error "Theme '$Name' is not registered."
        return
    }

    if (-not $Root) {
        Write-Error 'Use-WPFTheme: Unable to resolve a root element.'
        return
    }

    $resources = $Root.Resources
    $oldThemes = $resources.MergedDictionaries | Where-Object {
        $_.Contains('__WPFThemeName')
    }

    foreach ($dictionary in @($oldThemes)) {
        [void] $resources.MergedDictionaries.Remove($dictionary)
    }

    $dictionary = $script:WPFThemeTable[$Name]
    [void] $resources.MergedDictionaries.Add($dictionary)

    if (-not $script:WPFThemeState) {
        $script:WPFThemeState = [ordered]@{}
    }

    $script:WPFThemeState.ActiveTheme = $Name
}
