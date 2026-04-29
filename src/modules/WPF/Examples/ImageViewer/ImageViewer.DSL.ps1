using namespace Microsoft
using namespace System.Collections.Generic
using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Input
using namespace System.Windows.Media

<#
.SYNOPSIS
    Creates a simple image viewer.

.DESCRIPTION
    Creates a simple image viewer.

    Reads image files from the working directory and allows cycling between
    them using the forward/back buttons. Loops around from front to back and
    vice versa.
#>

# Change to the script directory if we're not in it.
if ($PSScriptRoot -and $PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'
$DebugPreference = 'Continue'

Import-Module ../.. -Force

# Define the Image Viewer GUI

Import "$PSScriptRoot/ImageViewer.Styles.ps1"
Import "$PSScriptRoot/functions/*.ps1"

# MARK: WINDOW
Window 'Window' {
    $this.Title = 'Image Viewer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.AllowDrop = $true
    $this.WindowState = [WindowState]::Maximized
    $this.Tag = New-WPFObservableState @{
        IsFullScreen   = $false
        IsFileLoaded   = $false
        IsFitMode      = $true
        ZoomLevel      = 1.0
        RotationAngle  = 0
        OldWindowStyle = $this.WindowStyle
        OldWindowState = $this.WindowState
        OldResizeMode  = $this.ResizeMode
        CurrentTheme   = if (Get-WPFDarkModePreference) { 'Dark' } else { 'Light' }
        FileNavigator  = $null
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
                if (-not $State.IsFullScreen) { return }

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
        Invoke-ImageViewerUpdateNavigationIconStyle
    }

    Grid "Body" {
        $this.Margin = 5

        # MARK: MENU
        Row {
            Column 'Expand' {
                MenuBar 'Menu' {
                    $this.Height = 25
                    Bind Visibility Window.Tag.IsFullScreen -Invert

                    MenuItem '(F)ile/(O)pen' {
                        Shortcut 'Open' {
                            $Window = Reference 'Window'
                            $FileName = Get-WPFFileSelection -Type All -Category Image -Window $Window

                            # Return early if we failed to get a file
                            if (-not $FileName) {
                                return
                            }

                            Invoke-ImageViewerLoadFile -FileName $FileName
                        }
                    }
                    MenuItem '(F)ile/(E)xit' {
                        # TODO: Explore using existing Close AppCommand and adding input gesture
                        Shortcut 'CloseCommand' 'Ctrl+q' {
                            Write-Debug "Close command triggered. Closing window."
                            (Reference 'Window').Close()
                        }
                    }

                    MenuItem '(I)mage/(R)otate 90°' {
                        Shortcut 'Rotate' 'Ctrl+R' {
                            Invoke-ImageViewerRotate -Direction Clockwise
                        }
                    }

                    MenuItem '(I)mage/R(o)tate -90°' {
                        Shortcut 'RotateCounter' 'Ctrl+Shift+R' {
                            Invoke-ImageViewerRotate -Direction CounterClockwise
                        }
                    }

                    MenuItem '(V)iew/Zoom (I)n' {
                        Shortcut 'ZoomIn' 'Ctrl+Add' {
                            Invoke-ImageViewerSetZoom -Delta 0.10
                        }
                    }

                    MenuItem '(V)iew/Zoom (O)ut' {
                        Shortcut 'ZoomOut' 'Ctrl+Subtract' {
                            Invoke-ImageViewerSetZoom -Delta -0.10
                        }
                    }

                    MenuItem '(V)iew/(F)ullScreen' {
                        Shortcut 'FullScreen' 'F11' {
                            Write-Debug "Toggling full screen mode."
                            $Window = Reference 'Window'
                            $State = $Window.Tag
                            Set-WPFWindowFullScreen -IsFullScreen (-not $State.IsFullScreen)
                            if ($State.IsFitMode) {
                                Invoke-ImageViewerFitToWindow
                            }
                        }
                    }

                    MenuItem '(V)iew/Image Fit to (W)indow' {
                        When Click {
                            Invoke-ImageViewerFitToWindow
                        }
                    }

                    MenuItem '(V)iew/Image (A)ctual Size' {
                        When Click {
                            Invoke-ImageViewerSetZoom -Reset
                        }
                    }

                    MenuItem '(V)iew/(T)oggle Theme' {
                        Shortcut 'ToggleTheme' 'Ctrl+T' {
                            Invoke-ImageViewerToggleTheme
                        }
                    }

                    MenuItem '(H)elp/(A)bout' {
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
                # TODO:
                # * Needs to support Counter/Clockwise rotation.
                StackPanel 'ButtonPanel' {
                    $this.Orientation = [Orientation]::Horizontal
                    $this.HorizontalAlignment = [HorizontalAlignment]::Center
                    Bind Visibility Window.Tag.IsFullScreen -Invert

                    $ButtonSize = 56
                    $IconScale = 0.6
                    $IconPadding = [math]::Round(($ButtonSize * (1 - $IconScale)) / 2)
                    $ButtonCornerRadius = 8

                    Button 'BackButton' {
                        UseStyle 'ImageViewer.IconButton'
                        $this.Width = $ButtonSize
                        $this.Height = $ButtonSize
                        $this.Margin = 5
                        $this.Background = 'Transparent'
                        $this.BorderThickness = 0
                        Bind IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerNavigate -Direction Back }
                        Border {
                            $this.CornerRadius = $ButtonCornerRadius
                            $this.Padding = $IconPadding
                            $this.BorderThickness = 1
                            Resource Background ButtonBackground
                            Resource BorderBrush DisabledForeground

                            Path 'images/arrow-left-solid-full.svg' {
                                UseStyle 'ImageViewer.IconPath'
                            }
                        }
                    }
                    Button 'FitToWindowButton' {
                        UseStyle 'ImageViewer.IconButton'
                        $this.Width = $ButtonSize
                        $this.Height = $ButtonSize
                        $this.Margin = 5
                        $this.Background = 'Transparent'
                        $this.BorderThickness = 0
                        $this.ToolTip = 'Fit image to window'
                        Bind IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerFitToWindow }
                        Border {
                            $this.CornerRadius = $ButtonCornerRadius
                            $this.Padding = $IconPadding
                            $this.BorderThickness = 1
                            Resource Background ButtonBackground
                            Resource BorderBrush DisabledForeground

                            Path 'images/arrows-to-circle-solid-full.svg' {
                                UseStyle 'ImageViewer.IconPath'
                            }
                        }
                    }
                    Button 'ActualSizeButton' {
                        UseStyle 'ImageViewer.IconButton'
                        $this.Width = $ButtonSize
                        $this.Height = $ButtonSize
                        $this.Margin = 5
                        $this.Background = 'Transparent'
                        $this.BorderThickness = 0
                        $this.ToolTip = 'Actual size (100%)'
                        Bind IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerSetZoom -Reset }
                        Border {
                            $this.CornerRadius = $ButtonCornerRadius
                            $this.Padding = $IconPadding
                            $this.BorderThickness = 1
                            Resource Background ButtonBackground
                            Resource BorderBrush DisabledForeground

                            Path 'images/up-right-and-down-left-from-center-solid-full.svg' {
                                UseStyle 'ImageViewer.IconPath'
                            }
                        }
                    }
                    Button 'RotateButton' {
                        UseStyle 'ImageViewer.IconButton'
                        $this.Width = $ButtonSize
                        $this.Height = $ButtonSize
                        $this.Margin = 5
                        $this.Background = 'Transparent'
                        $this.BorderThickness = 0
                        $this.ToolTip = 'Rotate 90° clockwise'
                        Bind IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerRotate -Direction Clockwise }
                        Border {
                            $this.CornerRadius = $ButtonCornerRadius
                            $this.Padding = $IconPadding
                            $this.BorderThickness = 1
                            Resource Background ButtonBackground
                            Resource BorderBrush DisabledForeground

                            Path 'images/arrows-rotate-solid-full.svg' {
                                UseStyle 'ImageViewer.IconPath'
                            }
                        }
                    }
                    Button 'ForwardButton' {
                        UseStyle 'ImageViewer.IconButton'
                        $this.Width = $ButtonSize
                        $this.Height = $ButtonSize
                        $this.Margin = 5
                        $this.Background = 'Transparent'
                        $this.BorderThickness = 0
                        Bind IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerNavigate -Direction Forward }
                        Border {
                            $this.CornerRadius = $ButtonCornerRadius
                            $this.Padding = $IconPadding
                            $this.BorderThickness = 1
                            Resource Background ButtonBackground
                            Resource BorderBrush DisabledForeground

                            Path 'images/arrow-right-solid-full.svg' {
                                UseStyle 'ImageViewer.IconPath'
                            }
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
                    Bind Visibility Window.Tag.IsFullScreen -Invert

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
