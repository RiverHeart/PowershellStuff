function Stop-ImageViewerMouseIdleHide {
    [CmdletBinding()]
    param()

    Write-Debug "Stopping mouse idle hide."

    $Window = Reference 'Window'
    $State = $Window.Tag

    # Stop the timer
    if ($State.MouseIdleTimer) {
        $State.MouseIdleTimer.Stop()
    }

    # Remove the event handler if it exists
    if ($State.MouseMoveHandler) {
        $Window.remove_MouseMove($State.MouseMoveHandler)
        $State.MouseMoveHandler = $null
    }

    # Restore the cursor
    $Window.Cursor = [Cursors]::Arrow
}
