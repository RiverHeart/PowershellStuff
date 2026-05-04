
<#
.SYNOPSIS
    Updates icon colors in a button panel to match the current theme.

.DESCRIPTION
    Refreshes the Fill and Stroke colors of all button icons within the named
    panel based on the active theme (Light/Dark) and the current file state
    (loaded/not loaded).

    When a file is loaded, icons render in the theme's foreground color. When no
    file is loaded, icons render in the disabled foreground color to indicate
    unavailability.

.NOTES
    WPF Light/Dark theme support requires manual color updates; dynamic binding
    through resources alone does not propagate theme changes to existing Path
    objects. This function is called when theme changes occur and when files are
    loaded/unloaded.

.EXAMPLE
    Update-ImageViewerIcon -PanelName 'ButtonPanel'

    Refreshes all button icons inside the ButtonPanel StackPanel.
#>
function Update-ImageViewerIcon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PanelName
    )

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

    $Panel = Reference $PanelName
    if (-not $Panel) { return }

    $Buttons = Find-WPFChildNode -Node $Panel -Type ([System.Windows.Controls.Button]) -All

    foreach ($Button in $Buttons) {
        $Path = if ($Button.Content -is [System.Windows.Shapes.Path]) {
            $Button.Content
        } elseif ($Button.Content -is [System.Windows.DependencyObject]) {
            Find-WPFChildNode -Node $Button.Content -Type ([System.Windows.Shapes.Path])
        } else {
            $null
        }

        if ($Path -is [System.Windows.Shapes.Path]) {
            $Path.Fill = $IconBrush
            $Path.Stroke = $IconBrush
        }
    }
}
