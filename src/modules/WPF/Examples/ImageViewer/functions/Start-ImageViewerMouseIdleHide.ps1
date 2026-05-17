function Start-ImageViewerMouseIdleHide {
    [CmdletBinding()]
    param()

    Write-Debug "Starting mouse idle hide."

    $Window = Reference 'Window'
    $State = $Window.Tag

    # Create the timer if it doesn't exist
    if (-not $State.MouseIdleTimer) {
        $Timer = [System.Windows.Threading.DispatcherTimer]::new()
        $Timer.Interval = [TimeSpan]::FromSeconds(3)
        $TimerWindow = $Window
        $Timer.add_Tick({
            if (-not $TimerWindow.IsLoaded) {
                $this.Stop()
                return
            }

            $TimerWindow.Cursor = [Cursors]::None
            $this.Stop()
        }.GetNewClosure())
        $State.MouseIdleTimer = $Timer
    }

    # Define the MouseMove event handler
    $MouseMoveWindow = $Window
    $MouseMoveHandler = {
        param($sender, $event)

        # Reset the mouse idle timer on any mouse movement
        $sender.Tag.MouseIdleTimer.Stop()
        $sender.Tag.MouseIdleTimer.Start()

        # Restore the cursor
        if ($MouseMoveWindow.IsLoaded) {
            $MouseMoveWindow.Cursor = [Cursors]::Arrow
        }
    }.GetNewClosure()

    # Store the handler reference for later removal
    $State.MouseMoveHandler = $MouseMoveHandler

    # Wire up the event handler to the window
    $Window.add_MouseMove($MouseMoveHandler)

    # Start the timer
    $State.MouseIdleTimer.Start()
}
