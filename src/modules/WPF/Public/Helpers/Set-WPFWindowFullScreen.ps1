function Set-WPFWindowFullScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool] $IsFullScreen,

        [string] $WindowName = 'Window'
    )

    $Window = Reference $WindowName
    $State = $Window.Tag

    if ($IsFullScreen) {
        if (-not $State.IsFullScreen) {
            $State.OldWindowStyle = $Window.WindowStyle
            $State.OldWindowState = $Window.WindowState
            $State.OldResizeMode  = $Window.ResizeMode
        }

        # Force Normal first so the borderless Maximized transition applies correctly
        # even when the window is already maximized. Otherwise the taskbar remains visible.
        # There is a brief flicker but none of the other recommendations like SetWindowPos
        # with SWP_FRAMECHANGED worked reliably for me.
        $Window.WindowState = [WindowState]::Normal
        $Window.WindowStyle = [WindowStyle]::None
        $Window.ResizeMode  = [ResizeMode]::NoResize
        $Window.WindowState = [WindowState]::Maximized
    } else {
        $Window.WindowStyle = $State.OldWindowStyle
        $Window.WindowState = $State.OldWindowState
        $Window.ResizeMode  = $State.OldResizeMode
    }

    # Updating IsFullScreen triggers Watch callbacks on Menu and ButtonPanel visibility
    $State.IsFullScreen = $IsFullScreen
}
