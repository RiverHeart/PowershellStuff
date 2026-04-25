
# NOTE: Regrettably, the only way I've found to support Light/Dark themes
# is to update the icon colors manually.
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

    foreach ($ButtonName in @('BackButton', 'ForwardButton')) {
        $Button = Reference $ButtonName
        if (-not $Button) { continue }

        $Path = $Button.Content
        if ($Path -is [System.Windows.Shapes.Path]) {
            $Path.Fill = $IconBrush
            $Path.Stroke = $IconBrush
        }
    }
}
