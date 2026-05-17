function Start-ImageViewerSlideshow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0.5, 600)]
        [double] $IntervalSeconds
    )

    Write-Debug "Starting slideshow with interval '$IntervalSeconds' seconds."
    $Window = Reference 'Window'
    $State = $Window.Tag

    if (-not $State.IsFileLoaded) {
        return
    }

    if (-not $State.SlideshowTimer) {
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
                Invoke-ImageViewerNavigate -Direction Forward
            } catch {
                # If shutdown/context teardown races this tick, stop gracefully.
                $this.Stop()
            }
        }.GetNewClosure())

        $State.SlideshowTimer = $Timer
    }

    $State.SlideshowIntervalSeconds = $IntervalSeconds
    $State.SlideshowTimer.Interval = [TimeSpan]::FromSeconds($IntervalSeconds)
    $State.IsSlideshowActive = $true

    $State.SlideshowTimer.Stop()
    $State.SlideshowTimer.Start()

    if (-not $State.IsFullScreen) {
        Set-WPFWindowFullScreen -IsFullScreen $true
    }

    if ($State.IsFitMode) {
        Invoke-ImageViewerFitToWindow
    }
}
