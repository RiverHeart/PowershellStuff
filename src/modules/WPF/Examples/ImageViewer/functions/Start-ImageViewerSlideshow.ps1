<#
.SYNOPSIS
    Starts an image slideshow with a specified interval between slides.

.DESCRIPTION
    Initializes and starts a slideshow timer that automatically navigates
    forward through images at the specified interval. If the slideshow is
    already active, it updates the interval. The slideshow continues until
    it is stopped manually or the window is closed.

.EXAMPLE
    Starts the slideshow with a 5-second interval between slides.

    Start-ImageViewerSlideshow -IntervalSeconds 5
#>
function Start-ImageViewerSlideshow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0.5, 600)]
        [double] $IntervalSeconds,

        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    Write-Debug "Starting slideshow with interval '$IntervalSeconds' seconds."
    $Window = Get-WPFWindow -ContextId $ContextId -ErrorAction Stop
    if (-not $ContextId) {
        $ContextId = Get-WPFContextId -InputObject $Window -ErrorAction Stop
    }

    $TimerContextId = $ContextId
    $State = $Window.Tag

    if (-not $State.IsFileLoaded) {
        return
    }

    if (-not $State.AutoForwardTimer) {
        Write-Debug "Initializing slideshow timer."

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
                Invoke-ImageViewerNavigate -Direction Forward -ContextId $TimerContextId
            } catch {
                # If shutdown/context teardown races this tick, stop gracefully.
                $this.Stop()
            }
        }.GetNewClosure())

        $State.AutoForwardTimer = $Timer
    }

    $State.IsFigureDrawingMode = $false
    $State.IsFigureDrawingPaused = $false
    $State.FigureDrawingPoseDurationsSeconds = $null
    $State.FigureDrawingPoseIndex = -1
    $State.FigureDrawingPoseRemainingSeconds = 0
    $State.FigureDrawingPoseEndsAtUtc = $null
    $State.FigureDrawingCountdownText = '00:00:00'
    $State.FigureDrawingLimiter = $null

    if ($State.FigureDrawingCountdownTimer) {
        $State.FigureDrawingCountdownTimer.Stop()
    }

    $State.AutoForwardIntervalSeconds = $IntervalSeconds
    $State.AutoForwardTimer.Interval = [TimeSpan]::FromSeconds($IntervalSeconds)
    $State.IsSlideshowActive = $true

    $State.AutoForwardTimer.Stop()
    $State.AutoForwardTimer.Start()

    if (-not $State.IsFullScreen) {
        Set-WPFWindowFullScreen -IsFullScreen $true
    }

    if ($State.IsFitMode) {
        Invoke-ImageViewerFitToWindow -ContextId $TimerContextId
    }
}
