<#
.SYNOPSIS
    Switches between light and dark WPF themes.

.DESCRIPTION
    Switches from the current theme to the alternate theme and applies it to
    the provided root element.

.EXAMPLE
    Switch-WPFTheme
#>
function Switch-WPFTheme {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $LightName = 'Light',

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $DarkName = 'Dark',

        [Parameter(Position = 2)]
        [System.Windows.FrameworkElement] $Root = (Reference 'Window')
    )

    if (-not $script:WPFThemeState) {
        $script:WPFThemeState = [ordered]@{}
    }

    $currentTheme = $script:WPFThemeState.ActiveTheme
    $nextTheme = if ($currentTheme -eq $DarkName) { $LightName } else { $DarkName }
    Use-WPFTheme -Name $nextTheme -Root $Root
}
