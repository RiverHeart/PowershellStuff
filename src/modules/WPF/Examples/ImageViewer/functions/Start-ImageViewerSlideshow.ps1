function Start-ImageViewerSlideshow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0.5, 600)]
        [double] $IntervalSeconds
    )

    $Window = Reference 'Window'
    $State = $Window.Tag

    if (-not $State.IsFileLoaded) {
        return
    }

    if (-not $State.SlideshowTimer) {
        $Timer = [System.Windows.Threading.DispatcherTimer]::new()

        $null = $Timer.add_Tick({
            $Window = Reference 'Window'
            $State = $Window.Tag
            if (-not $State.IsSlideshowActive -or -not $State.IsFileLoaded) {
                return
            }

            Invoke-ImageViewerNavigate -Direction Forward
        })

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
