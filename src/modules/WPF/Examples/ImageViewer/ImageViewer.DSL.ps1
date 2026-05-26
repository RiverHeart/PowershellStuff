using namespace Microsoft
using namespace System.Collections.Generic
using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Input
using namespace System.Windows.Media
using namespace System.Windows.Threading

<#
.SYNOPSIS
    Creates a simple image viewer.

.DESCRIPTION
    Creates a simple image viewer.

    Reads image files from the working directory and allows cycling between
    them using the forward/back buttons. Loops around from front to back and
    vice versa.
#>
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $FilePath,

    [Parameter()]
    [ValidateRange(0.5, 600)]
    [double] $SlideshowIntervalSeconds,

    [Parameter()]
    [ValidateRange(0, 600)]
    [double] $AutoCloseSeconds,

    [Parameter()]
    [switch] $StartFullscreen
)

# Change to the script directory if we're not in it.
if ($PSScriptRoot -and $PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'
$DebugPreference = 'Continue'

Import-Module ../.. -Force

Start-Sleep -Seconds 2

# Define the Image Viewer GUI

Import "$PSScriptRoot/ImageViewer.Styles.ps1"
Import "$PSScriptRoot/functions"

# MARK: WINDOW
Window 'Window' {
    $this.Title = 'Image Viewer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.AllowDrop = $true
    $this.WindowState = [WindowState]::Maximized
    State @{
        # Viewer State
        IsFullScreen   = $false
        IsFileLoaded   = $false
        IsFitMode      = $true
        ZoomLevel      = 1.0
        RotationAngle  = 0

        # Copy State
        IsCopyFeedbackActive = $false
        CopyFeedbackTimer = $null

        # Window State Backup (for toggling full screen)
        OldWindowStyle = $this.WindowStyle
        OldWindowState = $this.WindowState
        OldResizeMode  = $this.ResizeMode

        # Theme State
        CurrentTheme   = if (Get-WPFDarkModePreference) { 'Dark' } else { 'Light' }

        # Navigation State
        FileNavigator  = $null
        IsSlideshowActive = $false
        SlideshowTimer = $null
        SlideshowIntervalSeconds = 3.0

        # Command References
        SaveAsCommand  = $null
        SlideshowCommand = $null

        # Misc State
        MouseIdleTimer = $null
        MouseMoveHandler = $null
    }

    Use-WPFTheme -Name $this.Tag.CurrentTheme -Root $this

    # WARNING: A little debouncing might be needed to prevent multiple rapid
    # SizeChanged events from causing issues.
    When SizeChanged {
        if ((Reference 'Window').Tag.IsFitMode) {
            Invoke-ImageViewerFitToWindow
        }
    }

    # Window doesn't have a Command property like button so
    # you need to wire up an event.
    When KeyDown {
        param($sender, $event)

        switch ($event.Key) {
            'Escape' {
                $State = $this.Tag
                $StoppedSlideshow = $false
                if ($State.IsSlideshowActive) {
                    Stop-ImageViewerSlideshow
                    $StoppedSlideshow = $true
                }

                if (-not $State.IsFullScreen) {
                    if ($StoppedSlideshow) {
                        $event.Handled = $True
                    }
                    break
                }

                Set-WPFWindowFullScreen -IsFullScreen $False
                if ($State.IsFitMode) {
                    Invoke-ImageViewerFitToWindow
                }
                $event.Handled = $True
                break
            }
            'Left' {
                Invoke-ImageViewerNavigate -Direction Back
                $event.Handled = $True
                break
            }
            { $_ -in @('Right', 'Space') } {
                Invoke-ImageViewerNavigate -Direction Forward
                $event.Handled = $True
                break
            }
            { $_ -in @('D0', 'NumPad0') -and ([Keyboard]::Modifiers -band [ModifierKeys]::Control) } {
                Invoke-ImageViewerSetZoom -Reset
                $event.Handled = $True
                break
            }
        }
    }

    When Closing {
        Stop-ImageViewerSlideshow -Window $this
        Stop-ImageViewerMouseIdleHide -Window $this
    }

    When DragOver {
        param($sender, $event)

        if ($event.Data.GetDataPresent([DataFormats]::FileDrop)) {
            $event.Effects = [DragDropEffects]::Copy
        } else {
            $event.Effects = [DragDropEffects]::None
        }

        $event.Handled = $true
    }

    When Drop {
        param($sender, $event)

        if (-not $event.Data.GetDataPresent([DataFormats]::FileDrop)) {
            return
        }

        $Files = [string[]] $event.Data.GetData([DataFormats]::FileDrop)
        if ($Files.Count -gt 0) {
            Invoke-ImageViewerLoadFile -FileName $Files[0]
        }

        $event.Handled = $true
    }

    When 'Loaded' {
        Invoke-ImageViewerUpdateStatus

        if ($FilePath) {
            try {
                $ResolvedFilePath = (Resolve-Path -LiteralPath $FilePath -ErrorAction Stop).Path
                Invoke-ImageViewerLoadFile -FileName $ResolvedFilePath
            } catch {
                Write-Warning "Failed to resolve initial file path '$FilePath': $_"
            }
        }

        if ($StartFullscreen -and -not $this.Tag.IsFullScreen) {
            Set-WPFWindowFullScreen -IsFullScreen $true
        }

        if ($PSBoundParameters.ContainsKey('SlideshowIntervalSeconds')) {
            Start-ImageViewerSlideshow -IntervalSeconds $SlideshowIntervalSeconds
        }

    }

    Grid "Body" {
        $this.Margin = 5

        # MARK: MENU
        Row {
            Column 'Expand' {
                MenuBar 'Menu' {
                    $this.Height = 25
                    Watch Visibility Window.Tag.IsFullScreen -Invert

                    MenuItem '(F)ile/(O)pen' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'Open' {
                            $Window = Reference 'Window'
                            $FileName = Get-WPFFileSelection -Category Image -Window $Window

                            # Return early if we failed to get a file
                            if (-not $FileName) {
                                return
                            }

                            Invoke-ImageViewerLoadFile -FileName $FileName
                        }
                    }
                    MenuItem '(F)ile/(S)ave As' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'SaveAs' 'Ctrl+Shift+S' {
                            Execute {
                                $BitmapSource = Reference 'Viewer' -Property Source
                                $CurrentFile = (Reference 'Window').Tag.FileNavigator.CurrentFile
                                $SourcePath = $null
                                $InitialDirectory = $null

                                if ($null -ne $CurrentFile) {
                                    $SourcePath = $CurrentFile.FullName
                                    $InitialDirectory = $CurrentFile.DirectoryName
                                }

                                Invoke-ImageViewerSaveFileAs `
                                    -Image $BitmapSource `
                                    -SourcePath $SourcePath `
                                    -InitialDirectory $InitialDirectory
                            }
                            CanExecute {
                                [bool] (Reference 'Window').Tag.IsFileLoaded
                            }
                        }

                        # RelayCommand does not rely on CommandManager in this module,
                        # so we refresh availability explicitly when file state changes.
                        (Reference 'Window').Tag.SaveAsCommand = $this.Command
                    }
                    MenuItem '(F)ile/(E)xit' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'CloseCommand' 'Ctrl+q' {
                            Write-Debug "Close command triggered. Closing window."
                            (Reference 'Window').Close()
                        }
                    }

                    MenuItem '(I)mage/(R)otate 90°' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'Rotate' 'Ctrl+R' {
                            Invoke-ImageViewerRotate -Direction Clockwise
                        }
                    }

                    MenuItem '(I)mage/R(o)tate -90°' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'RotateCounter' 'Ctrl+Shift+R' {
                            Invoke-ImageViewerRotate -Direction CounterClockwise
                        }
                    }

                    MenuItem '(V)iew/Zoom (I)n' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'ZoomIn' 'Ctrl+Add' {
                            Invoke-ImageViewerSetZoom -Delta 0.10
                        }
                    }

                    MenuItem '(V)iew/Zoom (O)ut' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'ZoomOut' 'Ctrl+Subtract' {
                            Invoke-ImageViewerSetZoom -Delta -0.10
                        }
                    }

                    MenuItem '(V)iew/(F)ullScreen' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'FullScreen' 'F11' {
                            Write-Debug "Toggling full screen mode."
                            $Window = Reference 'Window'
                            $State = $Window.Tag
                            $IsEnteringFullScreen = -not $State.IsFullScreen

                            Set-WPFWindowFullScreen -IsFullScreen $IsEnteringFullScreen

                            if ($IsEnteringFullScreen) {
                                Start-ImageViewerMouseIdleHide
                            } else {
                                Stop-ImageViewerMouseIdleHide
                            }

                            if ($State.IsFitMode) {
                                Invoke-ImageViewerFitToWindow
                            }
                        }
                    }

                    MenuItem '(V)iew/(S)lideshow' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'Slideshow' 'F5' {
                            Execute {
                                Invoke-ImageViewerToggleSlideshow
                            }
                            CanExecute {
                                [bool] (Reference 'Window').Tag.IsFileLoaded
                            }
                        }

                        # RelayCommand does not auto-requery in this module.
                        (Reference 'Window').Tag.SlideshowCommand = $this.Command
                    }

                    MenuItem '(V)iew/Image Fit to (W)indow' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        When Click {
                            Invoke-ImageViewerFitToWindow
                        }
                    }

                    MenuItem '(V)iew/Image (A)ctual Size' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        When Click {
                            Invoke-ImageViewerSetZoom -Reset
                        }
                    }

                    MenuItem '(V)iew/(T)oggle Theme' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        Command 'ToggleTheme' 'Ctrl+T' {
                            Invoke-ImageViewerToggleTheme
                        }
                    }

                    MenuItem '(H)elp/(A)bout' {
                        UseStyle 'ImageViewer.UnthemedMenuItem'

                        When Click {
                            Invoke-ImageViewerShowAbout
                        }
                    }
                }
            }
        }

        # MARK: IMG VIEWER
        Row 'Expand' {
            Column {
                # In case the image is larger than the window, use the ScrollViewer
                # to adjust the view window.
                ScrollViewer 'ScrollViewer' {
                    $this.VerticalScrollbarVisibility = [ScrollBarVisibility]::Auto
                    $this.HorizontalScrollbarVisibility = [ScrollBarVisibility]::Auto
                    $this.Background = 'Transparent'

                    When PreviewMouseWheel {
                        param($sender, $event)

                        if (-not ([Keyboard]::Modifiers -band [ModifierKeys]::Control)) {
                            return
                        }

                        $Delta = if ($event.Delta -gt 0) { 0.10 } else { -0.10 }
                        Invoke-ImageViewerSetZoom -Delta $Delta
                        $event.Handled = $true
                    }

                    Image 'Viewer' {
                        $this.VerticalAlignment = [VerticalAlignment]::Center  # Center image to mirror how most image viewers work.
                        $this.StretchDirection = [StretchDirection]::DownOnly  # Prevent image from stretching across the entire window.
                    }
                }
            }
        }

        # MARK: TOOLBAR
        Row {
            Column {
                StackPanel 'ButtonPanel' {
                    $this.Orientation = [Orientation]::Horizontal
                    $this.HorizontalAlignment = [HorizontalAlignment]::Center
                    Watch Visibility Window.Tag.IsFullScreen -Invert

                    Button 'CopyButton' {
                        UseStyle 'ImageViewer.IconButton'
                        Watch IsEnabled Window.Tag.IsFileLoaded
                        Watch ToolTip Window.Tag.IsCopyFeedbackActive -Converter {
                            if ($_) { 'Copied to clipboard' } else { 'Copy image to clipboard' }
                        }
                        Watch Content Window.Tag.IsCopyFeedbackActive -Converter {
                            if ($_) {
                                Path 'images/clipboard-check-solid-full.svg' {
                                    UseStyle 'ImageViewer.IconPath'
                                }
                            } else {
                                Path 'images/clipboard-solid-full.svg' {
                                    UseStyle 'ImageViewer.IconPath'
                                }
                            }
                        }

                        When 'Click' {
                            try {
                                Set-WPFClipboard -InputObject (Reference 'Viewer') -ErrorAction Stop
                                Invoke-ImageViewerCopyFeedback -Success
                            } catch {
                                Invoke-ImageViewerCopyFeedback
                            }
                        }
                    }
                    Button 'ZoomModeButton' {
                        UseStyle 'ImageViewer.IconButton'
                        Watch IsEnabled Window.Tag.IsFileLoaded
                        Watch ToolTip Window.Tag.IsFitMode -Converter {
                            if ($_) { 'Actual size (100%)' } else { 'Fit image to window' }
                        }
                        Watch Content Window.Tag.IsFitMode -Converter {
                            if ($_) {
                                Path 'images/up-right-and-down-left-from-center-solid-full.svg' {
                                    UseStyle 'ImageViewer.IconPath'
                                }
                            } else {
                                Path 'images/arrows-to-circle-solid-full.svg' {
                                    UseStyle 'ImageViewer.IconPath'
                                }
                            }
                        }

                        When 'Click' {
                            if ((Reference 'Window').Tag.IsFitMode) {
                                Invoke-ImageViewerSetZoom -Reset
                            } else {
                                Invoke-ImageViewerFitToWindow
                            }
                        }
                    }
                    Button 'RotateButton' {
                        UseStyle 'ImageViewer.IconButton'
                        $this.ToolTip = 'Rotate 90° clockwise'
                        Watch IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerRotate -Direction Clockwise }
                        Path 'images/arrows-rotate-solid-full.svg' {
                            UseStyle 'ImageViewer.IconPath'
                        }
                    }
                    Button 'BackButton' {
                        UseStyle 'ImageViewer.IconButton'
                        Watch IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerNavigate -Direction Back }
                        Path 'images/arrow-left-solid-full.svg' {
                            UseStyle 'ImageViewer.IconPath'
                        }
                    }
                    Button 'ForwardButton' {
                        UseStyle 'ImageViewer.IconButton'
                        Watch IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerNavigate -Direction Forward }
                        Path 'images/arrow-right-solid-full.svg' {
                            UseStyle 'ImageViewer.IconPath'
                        }
                    }
                }
            }
        }

        # MARK: STATUS BAR
        Row {
            Column 'Expand' {
                DockPanel 'StatusPanel' {
                    $this.Margin = 5, 0, 5, 0
                    Watch Visibility Window.Tag.IsFullScreen -Invert

                    Label 'StatusFileLabel' {
                        $this.Content = 'No image loaded'
                        [DockPanel]::SetDock($this, [Dock]::Left)
                    }
                    Label 'StatusIndexLabel' {
                        $this.Content = '0/0'
                        [DockPanel]::SetDock($this, [Dock]::Right)
                    }
                    Label 'StatusDetailsLabel' {
                        $this.Content = '-'
                        [DockPanel]::SetDock($this, [Dock]::Right)
                    }
                    Label 'StatusZoomLabel' {
                        $this.Content = '100%'
                        [DockPanel]::SetDock($this, [Dock]::Right)
                    }
                }
            }
        }
    }
} | Show-WPFWindow
