function Invoke-ImageViewerUpdateFigureDrawingCountdown {
    [CmdletBinding()]
    param()

    $Window = Get-WPFWindow -ErrorAction SilentlyContinue
    if ($null -eq $Window) {
        return
    }

    $State = $Window.Tag
    if ($null -eq $State) {
        return
    }

    if (-not $State.IsFigureDrawingMode) {
        $State.FigureDrawingCountdownText = '00:00:00'
        return
    }

    if ($State.FigureDrawingPoseRemainingSeconds -lt 0) {
        $State.FigureDrawingPoseRemainingSeconds = 0
    }

    if (-not $State.IsFigureDrawingPaused -and $State.FigureDrawingPoseEndsAtUtc) {
        $NowUtc = [DateTime]::UtcNow
        $RemainingSeconds = ($State.FigureDrawingPoseEndsAtUtc - $NowUtc).TotalSeconds
        $State.FigureDrawingPoseRemainingSeconds = [Math]::Max(0.0, [double] $RemainingSeconds)
    }

    $DisplaySeconds = [int] [Math]::Ceiling([double] $State.FigureDrawingPoseRemainingSeconds)
    $DisplayTime = [TimeSpan]::FromSeconds([Math]::Max(0, $DisplaySeconds))
    $State.FigureDrawingCountdownText = $DisplayTime.ToString('hh\:mm\:ss')
}
