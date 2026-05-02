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
        $State.OldWindowStyle = $Window.WindowStyle
        $State.OldWindowState = $Window.WindowState
        $State.OldResizeMode  = $Window.ResizeMode

        $Window.WindowStyle = [WindowStyle]::None
        $Window.WindowState = [WindowState]::Maximized
        $Window.ResizeMode  = [ResizeMode]::NoResize
    } else {
        $Window.WindowStyle = $State.OldWindowStyle
        $Window.WindowState = $State.OldWindowState
        $Window.ResizeMode  = $State.OldResizeMode
    }

    # Updating IsFullScreen triggers React callbacks on Menu and ButtonPanel visibility
    $State.IsFullScreen = $IsFullScreen
}
