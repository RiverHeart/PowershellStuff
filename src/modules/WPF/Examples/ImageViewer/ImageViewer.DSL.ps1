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
if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'
$DebugPreference = 'Continue'

Import-Module ../.. -Force

function Invoke-ImageViewerNavigate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Back', 'Forward')]
        [string] $Direction
    )

    $State = (Reference 'Window').Tag
    if (-not $State.IsFileLoaded) { return }
    $Navigator = $State.FileNavigator
    if (-not $Navigator.CurrentFile) { return }

    if ($Direction -eq 'Back') { $Navigator.MovePrevious() } else { $Navigator.MoveNext() }
    (Reference 'Viewer').Source = $Navigator.CurrentFile.FullName
}

function Set-ImageViewerFullScreen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool] $IsFullScreen
    )

    $Window = Reference 'Window'
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

    # Updating IsFullScreen triggers Bind callbacks on Menu and ButtonPanel visibility
    $State.IsFullScreen = $IsFullScreen
}

# Define the Image Viewer GUI
Window 'Window' {
    $this.Title = 'Image Viewer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Tag = New-WPFObservableState @{
        IsFullScreen   = $false
        IsFileLoaded   = $false
        OldWindowStyle = [WindowStyle]::SingleBorderWindow
        OldWindowState = [WindowState]::Normal
        OldResizeMode  = [ResizeMode]::CanResize
        FileNavigator  = $null
    }

    # Window doesn't have a Command property like button so
    # you need to wire up an event.
    When KeyDown {
        param($sender, $event)

        switch ($event.Key) {
            'Escape' {
                $State = $this.Tag
                if (-not $State.IsFullScreen) { return }

                Set-ImageViewerFullScreen -IsFullScreen $False
                $event.Handled = $True
                break
            }
            'F11' {
                $State = $this.Tag
                Set-ImageViewerFullScreen -IsFullScreen (-not $State.IsFullScreen)
                $event.Handled = $True
                break
            }
            'Left' {
                Invoke-ImageViewerNavigate -Direction Back
                $event.Handled = $True
                break
            }
            'Right' {
                Invoke-ImageViewerNavigate -Direction Forward
                $event.Handled = $True
                break
            }
        }
    }

    Grid "Body" {
        $this.Margin = 5

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

                            $Viewer = Reference 'Viewer'
                            $Viewer.Source = $FileName

                            $State = $Window.Tag
                            $State.FileNavigator = New-WPFFileNavigator -Path $FileName -Category Image
                            $State.IsFileLoaded   = $true
                        }
                    }
                    MenuItem '(F)ile/(E)xit' {
                        # TODO: Explore using existing Close AppCommand and adding input gesture
                        Shortcut 'CloseCommand' 'Ctrl+q' {
                            (Reference 'Window').Close()
                        }
                    }

                    MenuItem '(V)iew/(F)ullScreen' {
                        Shortcut 'FullScreen' 'F11' {
                            $Window = Reference 'Window'
                            $State = $Window.Tag
                            Set-ImageViewerFullScreen -IsFullScreen (-not $State.IsFullScreen)
                        }
                    }

                    MenuItem '(H)elp/(A)bout' {
                        When Click {
                            # TODO: Open a model window here
                            Write-Host 'Implement Me'
                        }
                    }
                }
            }
        }

        # TODO:
        # * Background for this row should be black by default but configurable.
        #   * Maybe check user's OS for DarkMode preference
        Row 'Expand' {
            Column {
                # In case the image is larger than the window, use the ScrollViewer
                # to adjust the view window.
                ScrollViewer 'ScrollViewer' {
                    $this.VerticalScrollbarVisibility = [ScrollBarVisibility]::Auto
                    $this.HorizontalScrollbarVisibility = [ScrollBarVisibility]::Auto

                    Image 'Viewer' {
                        $this.VerticalAlignment = [VerticalAlignment]::Center  # Center image to mirror how most image viewers work.
                        $this.StretchDirection = [StretchDirection]::DownOnly  # Prevent image from stretching across the entire window.
                    }
                }
            }
        }

        Row {
            Column {
                # TODO:
                # * Needs to support Counter/Clockwise rotation.
                # * Needs to support "Fit to Window" and "Actual Image Size"
                # * Needs to support arrow key/spacebar movement
                StackPanel 'ButtonPanel' {
                    $this.Orientation = [Orientation]::Horizontal
                    $this.HorizontalAlignment = [HorizontalAlignment]::Center
                    Bind Visibility Window.Tag.IsFullScreen -Invert

                    Button 'BackButton' {
                        $this.Width = 75
                        $this.Margin = 5
                        Bind IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerNavigate -Direction Back }
                        Path 'images/arrow-left-solid-full.svg'
                    }
                    Button 'ForwardButton' {
                        $this.Width = 75
                        $this.Margin = 5
                        Bind IsEnabled Window.Tag.IsFileLoaded

                        When 'Click' { Invoke-ImageViewerNavigate -Direction Forward }
                        Path 'images/arrow-right-solid-full.svg'
                    }
                }
            }
        }
    }
} | Show-WPFWindow
