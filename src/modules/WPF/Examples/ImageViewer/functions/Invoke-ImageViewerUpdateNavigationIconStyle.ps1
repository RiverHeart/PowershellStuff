
<#
.SYNOPSIS
    Updates the navigation button icon colors to match the current theme.

.DESCRIPTION
    Refreshes the Fill and Stroke colors of all navigation button icons (Back, FitToWindow, ActualSize, Forward)
    based on the active theme (Light/Dark) and the current file state (loaded/not loaded).

    When a file is loaded, icons render in the theme's foreground color. When no file is loaded, icons render
    in the disabled foreground color to indicate unavailability.

.NOTES
    WPF Light/Dark theme support requires manual color updates; dynamic binding through resources alone does not
    propagate theme changes to existing Path objects. This function is called when theme changes occur and when
    files are loaded/unloaded.

    Locates icons inside button Border containers using Find-WPFChildPath when needed.

.EXAMPLE
    Invoke-ImageViewerUpdateNavigationIconStyle

    Refreshes all navigation button icons to match current theme and file state.
#>
function Invoke-ImageViewerUpdateNavigationIconStyle {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    $State = $Window.Tag
    $IconBrushKey = if ($State.IsFileLoaded) { 'Foreground' } else { 'DisabledForeground' }
    $IconBrush = $Window.TryFindResource($IconBrushKey)

    if (-not $IconBrush) {
        $IconBrush = if ($State.IsFileLoaded) {
            [System.Windows.Media.Brushes]::White
        } else {
            [System.Windows.Media.Brushes]::Gray
        }
    }

    $Buttons = @(
        'BackButton', 'FitToWindowButton', 'ActualSizeButton', 'ForwardButton'
        'RotateButton'
    )

    foreach ($ButtonName in $Buttons) {
        $Button = Reference $ButtonName
        if (-not $Button) { continue }

        $Path = if ($Button.Content -is [System.Windows.Shapes.Path]) {
            $Button.Content
        } elseif ($Button.Content -is [System.Windows.DependencyObject]) {
            Find-WPFChildPath -Node $Button.Content
        } else {
            $null
        }

        if ($Path -is [System.Windows.Shapes.Path]) {
            $Path.Fill = $IconBrush
            $Path.Stroke = $IconBrush
        }
    }
}
