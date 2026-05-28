function Test-ImageViewerShouldNavigate {
    [CmdletBinding()]
    param()

    $ScrollViewer = Reference 'ScrollViewer'
    if (-not $ScrollViewer) {
        return $true
    }

    # Keep arrow keys available for panning while the ScrollViewer has focus.
    if (-not $ScrollViewer.IsKeyboardFocusWithin) {
        return $true
    }

    $ScrollableWidth = [double] $ScrollViewer.ScrollableWidth
    return $ScrollableWidth -le 0
}
