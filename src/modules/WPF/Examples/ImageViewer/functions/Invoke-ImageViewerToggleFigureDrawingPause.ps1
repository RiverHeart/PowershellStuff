function Invoke-ImageViewerToggleFigureDrawingPause {
    [CmdletBinding()]
    param()

    $Window = Get-WPFWindow
    $State = $Window.Tag

    if (-not $State.IsFigureDrawingMode) {
        return
    }

    if ($State.IsFigureDrawingPaused) {
        $ResumeSeconds = [Math]::Max(0.1, [double] $State.FigureDrawingPoseRemainingSeconds)

        $State.IsFigureDrawingPaused = $false
        $State.FigureDrawingPoseEndsAtUtc = [DateTime]::UtcNow.AddSeconds($ResumeSeconds)
        if ($State.AutoForwardTimer) {
            $State.AutoForwardIntervalSeconds = $ResumeSeconds
            $State.AutoForwardTimer.Interval = [TimeSpan]::FromSeconds($ResumeSeconds)
            $State.AutoForwardTimer.Start()
        }

        if ($State.FigureDrawingCountdownTimer) {
            $State.FigureDrawingCountdownTimer.Start()
        }

        Invoke-ImageViewerUpdateFigureDrawingCountdown
        return
    }

    if ($State.FigureDrawingPoseEndsAtUtc) {
        $RemainingSeconds = ($State.FigureDrawingPoseEndsAtUtc - [DateTime]::UtcNow).TotalSeconds
        $State.FigureDrawingPoseRemainingSeconds = [Math]::Max(0.0, [double] $RemainingSeconds)
    }

    $State.IsFigureDrawingPaused = $true

    if ($State.AutoForwardTimer) {
        $State.AutoForwardTimer.Stop()
    }

    if ($State.FigureDrawingCountdownTimer) {
        $State.FigureDrawingCountdownTimer.Stop()
    }

    Invoke-ImageViewerUpdateFigureDrawingCountdown
}
