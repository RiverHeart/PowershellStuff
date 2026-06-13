function Start-ImageViewerFigureDrawingMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 600)]
        [int] $TotalMinutes,

        [Parameter()]
        [ValidateSet('Warmup', 'Balanced', 'StudyHeavy')]
        [string] $Preset = 'Balanced',

        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    Write-Debug "Starting figure drawing mode with preset '$Preset' and session length '$TotalMinutes' minutes."
    $Window = Get-WPFWindow -ContextId $ContextId -ErrorAction Stop
    if (-not $ContextId) {
        $ContextId = Get-WPFContextId -InputObject $Window -ErrorAction Stop
    }

    $TimerContextId = $ContextId
    $State = $Window.Tag

    if (-not $State.IsFileLoaded) {
        return
    }

    $ImageCount = [int] $State.FileNavigator.Files.Count
    if ($ImageCount -lt 1) {
        return
    }

    $Schedule = New-ImageViewerFigureDrawSchedule -TotalMinutes $TotalMinutes -ImageCount $ImageCount -Preset $Preset
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

                    Invoke-ImageViewerNavigate -Direction Forward -ContextId $TimerContextId
                    $TimerState.FigureDrawingPoseIndex = $NextPoseIndex
                    $NextDuration = [double] $TimerState.FigureDrawingPoseDurationsSeconds[$NextPoseIndex]
                    $TimerState.FigureDrawingPoseRemainingSeconds = $NextDuration
                    $TimerState.FigureDrawingPoseEndsAtUtc = [DateTime]::UtcNow.AddSeconds($NextDuration)
                    $TimerState.AutoForwardIntervalSeconds = $NextDuration
                    $TimerState.AutoForwardTimer.Interval = [TimeSpan]::FromSeconds($NextDuration)
                    Invoke-ImageViewerUpdateFigureDrawingCountdown -ContextId $TimerContextId
                    return
                }

                Invoke-ImageViewerNavigate -Direction Forward -ContextId $TimerContextId
            } catch {
                # If shutdown/context teardown races this tick, stop gracefully.
                $this.Stop()
            }
        }.GetNewClosure())

        $State.AutoForwardTimer = $Timer
    }

    if (-not $State.FigureDrawingCountdownTimer) {
        $CountdownTimer = [System.Windows.Threading.DispatcherTimer]::new()
        $CountdownTimer.Interval = [TimeSpan]::FromMilliseconds(250)

        $null = $CountdownTimer.add_Tick({
            Invoke-ImageViewerUpdateFigureDrawingCountdown -ContextId $TimerContextId
        }.GetNewClosure())

        $State.FigureDrawingCountdownTimer = $CountdownTimer
    }

    $State.IsFigureDrawingMode = $true
    $State.IsFigureDrawingPaused = $false
    $State.FigureDrawingPreset = $Preset
    $State.FigureDrawingLimiter = $Schedule.Limiter
    $State.FigureDrawingTotalMinutes = $TotalMinutes
    $State.FigureDrawingPoseIndex = 0
    $State.FigureDrawingPoseDurationsSeconds = [System.Collections.Generic.List[double]]::new()

    foreach ($DurationSeconds in $Schedule.DurationsSeconds) {
        $State.FigureDrawingPoseDurationsSeconds.Add([double] $DurationSeconds)
    }

    $FirstDuration = [double] $State.FigureDrawingPoseDurationsSeconds[0]
    $State.FigureDrawingPoseRemainingSeconds = $FirstDuration
    $State.FigureDrawingPoseEndsAtUtc = [DateTime]::UtcNow.AddSeconds($FirstDuration)
    $State.AutoForwardIntervalSeconds = $FirstDuration
    $State.AutoForwardTimer.Interval = [TimeSpan]::FromSeconds($FirstDuration)
    $State.IsSlideshowActive = $true

    $State.AutoForwardTimer.Stop()
    $State.AutoForwardTimer.Start()
    $State.FigureDrawingCountdownTimer.Stop()
    $State.FigureDrawingCountdownTimer.Start()
    Invoke-ImageViewerUpdateFigureDrawingCountdown -ContextId $TimerContextId

    if (-not $State.IsFullScreen) {
        Set-WPFWindowFullScreen -IsFullScreen $true
    }

    if ($State.IsFitMode) {
        Invoke-ImageViewerFitToWindow -ContextId $TimerContextId
    }
}
