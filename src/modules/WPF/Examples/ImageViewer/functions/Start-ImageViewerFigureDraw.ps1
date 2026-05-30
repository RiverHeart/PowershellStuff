function Start-ImageViewerFigureDrawingMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 600)]
        [int] $TotalMinutes
    )

    Write-Debug "Starting figure drawing mode with session length '$TotalMinutes' minutes."
    $Window = Reference 'Window'
    $State = $Window.Tag

    if (-not $State.IsFileLoaded) {
        return
    }

    $ImageCount = [int] $State.FileNavigator.Files.Count
    if ($ImageCount -lt 1) {
        return
    }

    $Schedule = New-ImageViewerFigureDrawSchedule -TotalMinutes $TotalMinutes -ImageCount $ImageCount
    if (-not $Schedule -or $Schedule.PoseCount -lt 1) {
        return
    }

    Write-Debug "Figure drawing schedule poses: $($Schedule.PoseCount), limiter: $($Schedule.Limiter)."

    if (-not $State.AutoForwardTimer) {
        Write-Debug "Initializing figure drawing timer."

        $Timer = [System.Windows.Threading.DispatcherTimer]::new()
        $TimerWindow = $Window
        $TimerState = $State

        $null = $Timer.add_Tick({
            if (-not $TimerState.IsSlideshowActive -or -not $TimerState.IsFileLoaded) {
                return
            }

            if (-not $TimerWindow.IsLoaded) {
                $this.Stop()
                return
            }

            try {
                if ($TimerState.IsFigureDrawingMode) {
                    $NextPoseIndex = [int] $TimerState.FigureDrawingPoseIndex + 1
                    if ($NextPoseIndex -ge $TimerState.FigureDrawingPoseDurationsSeconds.Count) {
                        Stop-ImageViewerSlideshow -Window $TimerWindow
                        return
                    }

                    Invoke-ImageViewerNavigate -Direction Forward
                    $TimerState.FigureDrawingPoseIndex = $NextPoseIndex
                    $NextDuration = [double] $TimerState.FigureDrawingPoseDurationsSeconds[$NextPoseIndex]
                    $TimerState.AutoForwardIntervalSeconds = $NextDuration
                    $TimerState.AutoForwardTimer.Interval = [TimeSpan]::FromSeconds($NextDuration)
                    return
                }

                Invoke-ImageViewerNavigate -Direction Forward
            } catch {
                # If shutdown/context teardown races this tick, stop gracefully.
                $this.Stop()
            }
        }.GetNewClosure())

        $State.AutoForwardTimer = $Timer
    }

    $State.IsFigureDrawingMode = $true
    $State.FigureDrawingLimiter = $Schedule.Limiter
    $State.FigureDrawingTotalMinutes = $TotalMinutes
    $State.FigureDrawingPoseIndex = 0
    $State.FigureDrawingPoseDurationsSeconds = [System.Collections.Generic.List[double]]::new()

    foreach ($DurationSeconds in $Schedule.DurationsSeconds) {
        $State.FigureDrawingPoseDurationsSeconds.Add([double] $DurationSeconds)
    }

    $FirstDuration = [double] $State.FigureDrawingPoseDurationsSeconds[0]
    $State.AutoForwardIntervalSeconds = $FirstDuration
    $State.AutoForwardTimer.Interval = [TimeSpan]::FromSeconds($FirstDuration)
    $State.IsSlideshowActive = $true

    $State.AutoForwardTimer.Stop()
    $State.AutoForwardTimer.Start()

    if (-not $State.IsFullScreen) {
        Set-WPFWindowFullScreen -IsFullScreen $true
    }

    if ($State.IsFitMode) {
        Invoke-ImageViewerFitToWindow
    }
}
