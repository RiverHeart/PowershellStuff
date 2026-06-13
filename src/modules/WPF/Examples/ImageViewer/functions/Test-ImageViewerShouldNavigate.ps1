<#
.SYNOPSIS
    Determines whether the ImageViewer should navigate to the next or previous image.

.DESCRIPTION
    This function checks the state of the ScrollViewer in the ImageViewer to decide
    whether arrow key presses should trigger navigation to the next or previous image
    or if they should be used for panning the current image.
#>
function Test-ImageViewerShouldNavigate {
    [CmdletBinding()]
    [OutputType([bool])]
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
