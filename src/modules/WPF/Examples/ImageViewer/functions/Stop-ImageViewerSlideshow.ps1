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

    if ($State.FigureDrawingCountdownTimer) {
        $State.FigureDrawingCountdownTimer.Stop()
    }

    $State.IsSlideshowActive = $false
    $State.IsFigureDrawingMode = $false
    $State.IsFigureDrawingPaused = $false
    $State.FigureDrawingPoseDurationsSeconds = $null
    $State.FigureDrawingPoseIndex = -1
    $State.FigureDrawingPoseRemainingSeconds = 0
    $State.FigureDrawingPoseEndsAtUtc = $null
    $State.FigureDrawingCountdownText = '00:00:00'
    $State.FigureDrawingLimiter = $null
}
