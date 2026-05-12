function Stop-ImageViewerMouseIdleHide {
    [CmdletBinding()]
    param(
        [System.Windows.Window] $Window
    )

    Write-Debug "Stopping mouse idle hide."

    if ($null -eq $Window) {
        $Window = Reference 'Window' -ErrorAction SilentlyContinue
    }
    if ($null -eq $Window) {
        return
    }

    $State = $Window.Tag
    if ($null -eq $State) {
        return
    }

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
