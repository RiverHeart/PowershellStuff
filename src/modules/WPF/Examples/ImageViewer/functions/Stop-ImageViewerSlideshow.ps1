function Stop-ImageViewerSlideshow {
    [CmdletBinding()]
    param(
        [System.Windows.Window] $Window
    )

    Write-Debug "Stopping slideshow."

    if ($null -eq $Window) {
        $Window = Reference 'Window' -ErrorAction SilentlyContinue
    }
    if ($null -eq $Window) {
        return
    }

    $State = $Window.Tag
    if ($null -eq $State) {
        return
    }

    if ($State.AutoForwardTimer) {
        $State.AutoForwardTimer.Stop()
    }

    $State.IsSlideshowActive = $false
    $State.IsFigureDrawingMode = $false
    $State.FigureDrawingPoseDurationsSeconds = $null
    $State.FigureDrawingPoseIndex = -1
    $State.FigureDrawingLimiter = $null
}
