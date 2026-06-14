<#
.SYNOPSIS
    Toggles full screen mode for a WPF Window.

.DESCRIPTION
    When $IsFullScreen is $true, the specified window is set to borderless and
    maximized to cover the entire screen. When $IsFullScreen is $false, the window
    is restored to its previous WindowStyle, WindowState, and ResizeMode.

    If the window has a registered _WPFAppContent host (the default template does),
    it removes the margin, temporarily, to ensure the content fills the screen in
    fullscreen mode and restores it correctly when exiting fullscreen.

    The window's previous state is stored in its Tag property, so this function can be
    called multiple times to toggle full screen mode on and off without losing the
    original state.

    By default, this function targets the window registered as 'Window', but you can specify
    a different registered window name via the -WindowName parameter.
#>
function Set-WPFWindowFullScreen {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory)]
        [bool] $IsFullScreen,

        # Typed as an object to allow tests to pass in a mock PSObject
        # with Window-like properties.
        [Parameter(Mandatory, ParameterSetName = 'ByObject')]
        [ValidateNotNull()]
        [object] $Window,

        [Parameter(ParameterSetName = 'ByName')]
        [string] $WindowName = 'Window',

        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        if ($ContextId) {
            $Window = Reference -Name $WindowName -ContextId $ContextId -ErrorAction Stop
        } else {
            $Window = Reference -Name $WindowName -ErrorAction Stop
        }
    } elseif ($PSCmdlet.ParameterSetName -ne 'ByObject') {
        Write-Error 'Invalid parameter set. Use either -Window or -WindowName.'
        return
    }

    $State = $Window.Tag
    $AppContentHost = $null
    $ContentHostProperty = $Window.PSObject.Properties['_WPFAppContent']
    if ($ContentHostProperty -and $ContentHostProperty.Value -is [System.Windows.Controls.Grid]) {
        $AppContentHost = [System.Windows.Controls.Grid] $ContentHostProperty.Value
    }

    if ($IsFullScreen) {
        Write-Debug "Entering full screen mode for window '$($Window.Title)' (Name='$($Window.Name)')"

        if (-not $State.IsFullScreen) {
            $State.OldWindowStyle = $Window.WindowStyle
            $State.OldWindowState = $Window.WindowState
            $State.OldResizeMode  = $Window.ResizeMode

            if ($AppContentHost) {
                if (-not $State.PSObject.Properties['OldAppContentMargin']) {
                    $State | Add-Member -NotePropertyName OldAppContentMargin -NotePropertyValue $AppContentHost.Margin
                } else {
                    $State.OldAppContentMargin = $AppContentHost.Margin
                }
            }
        }

        # Force Normal first so the borderless Maximized transition applies correctly
        # even when the window is already maximized. Otherwise the taskbar remains visible.
        # There is a brief flicker but none of the other recommendations like SetWindowPos
        # with SWP_FRAMECHANGED worked reliably for me.
        $Window.WindowState = [WindowState]::Normal
        $Window.WindowStyle = [WindowStyle]::None
        $Window.ResizeMode  = [ResizeMode]::NoResize
        $Window.WindowState = [WindowState]::Maximized

        if ($AppContentHost) {
            Write-Debug "Removing content margin for full screen mode for window '$($Window.Title)' (Name='$($Window.Name)')"
            $AppContentHost.Margin = [System.Windows.Thickness]::new(0)
        }
    } else {
        Write-Debug "Exiting full screen mode for window '$($Window.Title)' (Name='$($Window.Name)')"

        $Window.WindowStyle = $State.OldWindowStyle
        $Window.WindowState = $State.OldWindowState
        $Window.ResizeMode  = $State.OldResizeMode

        if ($AppContentHost -and $State.PSObject.Properties['OldAppContentMargin']) {
            Write-Debug "Restoring original content margin for window '$($Window.Title)' (Name='$($Window.Name)')"
            $AppContentHost.Margin = [System.Windows.Thickness] $State.OldAppContentMargin
        }
    }

    # Updating IsFullScreen triggers Bind callbacks on Menu and ButtonPanel visibility
    $State.IsFullScreen = $IsFullScreen
}
