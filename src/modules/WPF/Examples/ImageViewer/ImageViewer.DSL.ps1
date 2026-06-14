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

# Define the Image Viewer GUI

Import "$PSScriptRoot/ImageViewer.Styles.ps1"
Import "$PSScriptRoot/functions"

# MARK: WINDOW
App 'Window' {
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

        IsSlideshowActive = $false
        IsFigureDrawingMode = $false
        IsFigureDrawingPaused = $false
        FigureDrawingPreset = 'Balanced'
        FigureDrawingTotalMinutes = 0
        FigureDrawingLimiter = $null
        FigureDrawingPoseIndex = -1
        FigureDrawingPoseRemainingSeconds = 0.0
        FigureDrawingPoseEndsAtUtc = $null
        FigureDrawingPoseDurationsSeconds = $null
        FigureDrawingCountdownText = '00:00:00'
        FigureDrawingCountdownTimer = $null

        IsAutoForwardActive = $false
        AutoForwardTimer = $null
        AutoForwardIntervalSeconds = 3.0

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

        # Command References
        SaveAsCommand  = $null
        SlideshowCommand = $null
        FigureDrawingCommand = $null

        # Misc State
        MouseIdleTimer = $null
        MouseMoveHandler = $null
    }

    Use-WPFTheme -Name $this.Tag.CurrentTheme -Root $this

    # WARNING: A little debouncing might be needed to prevent multiple rapid
    # SizeChanged events from causing issues.
    When SizeChanged {
        if ($this.Tag.IsFitMode) {
            Invoke-ImageViewerFitToWindow
        }
    }

    # Demonstrate keyboard event handling with the `Key` helper.
    Key 'Escape' {
        Write-Debug "Escape key pressed. Attempting to exit full screen mode if active."
        $State = $this.Tag
        $StoppedSlideshow = $false
        if ($State.IsSlideshowActive) {
            Stop-ImageViewerSlideshow
            $StoppedSlideshow = $true
        }

        if (-not $State.IsFullScreen) {
            if ($StoppedSlideshow) {
                $event.Handled = $true
            }
            return
        }

        Set-WPFWindowFullScreen -IsFullScreen $False
        if ($this.Tag.IsFitMode) {
            Invoke-ImageViewerFitToWindow
        }
        $Event.Handled = $true
    }

    # Demonstrate more general keyboard event handling with `When`. This is needed for
    # navigation keys since they require conditional handling based on the focused
    # control's scrollability.
    #
    # NOTE: Use PreviewKeyDown so navigation keys still work when focused controls
    # like ScrollViewer handle KeyDown internally.
    When PreviewKeyDown {
        param($sender, $event)

        switch ($event.Key) {
            'Left' {
                if (Test-ImageViewerShouldNavigate) {
                    Invoke-ImageViewerNavigate -Direction Back
                    $event.Handled = $True
                }
                break
            }
            { $_ -in @('Right', 'Space') } {
                if ($event.Key -eq [Key]::Space -or (Test-ImageViewerShouldNavigate)) {
                    Invoke-ImageViewerNavigate -Direction Forward
                    $event.Handled = $True
                }
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

    MenuBar 'Menu' {
        $this.Height = 25
        Bind Visibility -To Window.Tag.IsFullScreen -Invert

        MenuItem '(F)ile/(O)pen' {
            UseStyle 'ImageViewer.UnthemedMenuItem'

            Command 'Open' {
                $Window = Get-WPFWindow
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
                    $CurrentFile = (Get-WPFWindow).Tag.FileNavigator.CurrentFile
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
                    [bool] (Get-WPFWindow).Tag.IsFileLoaded
                }
            }

            # RelayCommand does not rely on CommandManager in this module,
            # so we refresh availability explicitly when file state changes.
            (Get-WPFWindow).Tag.SaveAsCommand = $this.Command
        }
        MenuItem '(F)ile/(E)xit' {
            UseStyle 'ImageViewer.UnthemedMenuItem'

            Command 'CloseCommand' 'Ctrl+q' {
                Write-Debug "Close command triggered. Closing window."
                (Get-WPFWindow).Close()
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
                $Window = Get-WPFWindow
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
                    [bool] (Get-WPFWindow).Tag.IsFileLoaded
                }
            }

            # RelayCommand does not auto-requery in this module.
            (Get-WPFWindow).Tag.SlideshowCommand = $this.Command
        }

        MenuItem '(V)iew/Figure (D)rawing Mode' {
            UseStyle 'ImageViewer.UnthemedMenuItem'

            Command 'FigureDrawingMode' 'F6' {
                Execute {
                    Invoke-ImageViewerToggleFigureDrawingMode
                }
                CanExecute {
                    [bool] (Get-WPFWindow).Tag.IsFileLoaded
                }
            }

            # RelayCommand does not auto-requery in this module.
            (Get-WPFWindow).Tag.FigureDrawingCommand = $this.Command
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

    Content {
        DockPanel 'MainPanel' {
            $this.LastChildFill = $true

            # MARK: IMG VIEWER
            # In case the image is larger than the window, use the ScrollViewer
            # to adjust the view window.
            Border 'FigureDrawingSidebar' {
                $this.Width = 260
                $this.Padding = 16
                $this.Margin = 6, 0, 0, 0
                $this.Background = '#E61C1C1C'
                $this.BorderThickness = 1
                $this.BorderBrush = '#FF4A4A4A'
                Dock Right
                Bind Visibility -To Window.Tag.IsFigureDrawingMode -Converter {
                    if ($_) { 'Visible' } else { 'Collapsed' }
                }

                StackPanel 'FigureDrawingSidebarStack' {
                    $this.VerticalAlignment = [VerticalAlignment]::Center
                    $this.HorizontalAlignment = [HorizontalAlignment]::Stretch

                    Label 'FigureDrawingCountdownLabel' {
                        $this.HorizontalAlignment = [HorizontalAlignment]::Center
                        $this.FontFamily = 'Consolas'
                        $this.FontSize = 46
                        $this.FontWeight = [FontWeights]::Bold
                        $this.Foreground = '#FFF8F8F8'
                        Bind Content -To Window.Tag.FigureDrawingCountdownText
                    }

                    Label 'FigureDrawingMetaLabel' {
                        $this.HorizontalAlignment = [HorizontalAlignment]::Center
                        $this.Foreground = '#FFD3D3D3'
                        Bind Content -To Window.Tag.IsFigureDrawingPaused -Converter {
                            if ($_) { 'Paused' } else { 'Running' }
                        }
                    }

                    Button 'FigureDrawingPauseButton' {
                        UseStyle 'ImageViewer.IconButton'
                        $this.HorizontalAlignment = [HorizontalAlignment]::Center
                        $this.Margin = 0, 20, 0, 0
                        Bind ToolTip -To Window.Tag.IsFigureDrawingPaused -Converter {
                            if ($_) { 'Resume figure drawing' } else { 'Pause figure drawing' }
                        }
                        Bind Content -To Window.Tag.IsFigureDrawingPaused -Converter {
                            if ($_) {
                                Path 'images/play-solid-full.svg' {
                                    UseStyle 'ImageViewer.IconPath'
                                }
                            } else {
                                Path 'images/pause-solid-full.svg' {
                                    UseStyle 'ImageViewer.IconPath'
                                }
                            }
                        }

                        When Click {
                            Invoke-ImageViewerToggleFigureDrawingPause
                        }
                    }
                }
            }

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

    Footer {
        # MARK: TOOLBAR
        StackPanel 'ButtonPanel' {
            $this.Orientation = [Orientation]::Horizontal
            $this.HorizontalAlignment = [HorizontalAlignment]::Center
            Bind Visibility -To Window.Tag.IsFullScreen -Invert

            Button 'CopyButton' {
                UseStyle 'ImageViewer.IconButton'
                Bind IsEnabled -To Window.Tag.IsFileLoaded
                Bind ToolTip -To Window.Tag.IsCopyFeedbackActive -Converter {
                    if ($_) { 'Copied to clipboard' } else { 'Copy image to clipboard' }
                }
                Bind Content -To Window.Tag.IsCopyFeedbackActive -Converter {
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
                Bind IsEnabled -To Window.Tag.IsFileLoaded
                Bind ToolTip -To Window.Tag.IsFitMode -Converter {
                    if ($_) { 'Actual size (100%)' } else { 'Fit image to window' }
                }
                Bind Content -To Window.Tag.IsFitMode -Converter {
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
                    if ((Get-WPFWindow).Tag.IsFitMode) {
                        Invoke-ImageViewerSetZoom -Reset
                    } else {
                        Invoke-ImageViewerFitToWindow
                    }
                }
            }

            Button 'RotateButton' {
                UseStyle 'ImageViewer.IconButton'
                $this.ToolTip = 'Rotate 90° clockwise'
                Bind IsEnabled -To Window.Tag.IsFileLoaded

                When 'Click' { Invoke-ImageViewerRotate -Direction Clockwise }
                Path 'images/arrows-rotate-solid-full.svg' {
                    UseStyle 'ImageViewer.IconPath'
                }
            }

            Button 'BackButton' {
                UseStyle 'ImageViewer.IconButton'
                Bind IsEnabled -To Window.Tag.IsFileLoaded

                When 'Click' { Invoke-ImageViewerNavigate -Direction Back }
                Path 'images/arrow-left-solid-full.svg' {
                    UseStyle 'ImageViewer.IconPath'
                }
            }
            Button 'ForwardButton' {
                UseStyle 'ImageViewer.IconButton'
                Bind IsEnabled -To Window.Tag.IsFileLoaded

                When 'Click' { Invoke-ImageViewerNavigate -Direction Forward }
                Path 'images/arrow-right-solid-full.svg' {
                    UseStyle 'ImageViewer.IconPath'
                }
            }
        }
    }

    # MARK: STATUS BAR
    StatusBar {
        $this.Margin = 0, 5, 0, 0
        Bind Visibility -To Window.Tag.IsFullScreen -Invert

        StatusBarItem 'StatusFileItem' {
            Dock Left

            Label 'StatusFileLabel' {
                $this.Content = 'No image loaded'
            }
        }

        StatusBarItem 'StatusIndexItem' {
            Dock Right

            Label 'StatusIndexLabel' {
                $this.Content = '0/0'
            }
        }

        StatusBarItem 'StatusDetailsItem' {
            Dock Right

            Label 'StatusDetailsLabel' {
                $this.Content = '-'
            }
        }

        StatusBarItem 'StatusZoomItem' {
            Dock Right

            Label 'StatusZoomLabel' {
                $this.Content = '100%'
            }
        }
    }
} | Show-WPFWindow
