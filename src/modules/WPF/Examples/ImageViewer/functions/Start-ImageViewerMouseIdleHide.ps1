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
        $Timer.add_Tick({
            $Window = (Reference 'Window')
            $Window.Cursor = [Cursors]::None
            $this.Stop()
        })
        $State.MouseIdleTimer = $Timer
    }

    # Define the MouseMove event handler
    $MouseMoveHandler = {
        param($sender, $event)

        # Reset the mouse idle timer on any mouse movement
        $sender.Tag.MouseIdleTimer.Stop()
        $sender.Tag.MouseIdleTimer.Start()

        # Restore the cursor
        $Window = (Reference 'Window')
        $Window.Cursor = [Cursors]::Arrow
    }

    # Store the handler reference for later removal
    $State.MouseMoveHandler = $MouseMoveHandler

    # Wire up the event handler to the window
    $Window.add_MouseMove($MouseMoveHandler)

    # Start the timer
    $State.MouseIdleTimer.Start()
}
