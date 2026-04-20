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

# Define the Image Viewer GUI
Window 'Window' {
    $this.Title = 'Image Viewer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Tag = @{}

    # Window doesn't have a Command property like button so
    # you need to wire up an event.
    When PreviewKeyDown {
        param($sender, $event)
        if ($event.key -ne 'Escape') { return }
        $this.WindowStyle = [WindowStyle]::SingleBorderWindow
        $this.WindowState = [WindowState]::Normal
        $this.ResizeMode = [ResizeMode]::CanResize
    }

    Grid "Body" {
        $this.Margin = 5

        Row {
            Column 'Expand' {
                MenuBar 'Menu' {
                    $this.Height = 25

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

                            $Window.Tag.FileNavigator = New-WPFFileNavigator -Path $FileName -Category Image

                            # Enable buttons
                            (Reference 'ForwardButton').IsEnabled = $True
                            (Reference 'BackButton').IsEnabled = $True
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
                            # TODO: Convert this into an extension method SetFullScreen([bool])
                            # so we can just (Reference 'Window').SetFullScreen($True)
                            $Window = Reference 'Window'
                            if ($Window.WindowState -eq [WindowState]::Maximized) {
                                $Window.WindowStyle = [WindowStyle]::SingleBorderWindow
                                $Window.WindowState = [WindowState]::Normal
                                $Window.ResizeMode = [ResizeMode]::CanResize
                                (Reference 'MenuBar').Visibility = 'Visible'
                                (Reference 'ButtonPanel').Visibility = 'Visible'
                            } else {
                                $Window.WindowStyle = [WindowStyle]::None
                                $Window.WindowState = [WindowState]::Maximized
                                $Window.ResizeMode = [ResizeMode]::NoResize
                                (Reference 'MenuBar').Visibility = 'Collapsed'
                                (Reference 'ButtonPanel').Visibility = 'Collapsed'
                            }
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

                    Button 'BackButton' {
                        $this.Width = 75
                        $this.Margin = 5
                        $this.IsEnabled = $False

                        # FIXME:
                        # Obvious in hindsight but it seems the closure I was using
                        # to support `$this` in Add-WPFHandler broke the scriptblock's
                        # ability to access script-scope variables reliably, so navigator
                        # state now lives on the Window.Tag property.
                        When 'Click' {
                            Write-Host "Back"
                            $Navigator = (Reference 'Window').Tag.FileNavigator
                            if (-not $Navigator -or -not $Navigator.CurrentFile) { return }
                            $Navigator.MovePrevious()
                            $Viewer = Reference 'Viewer'
                            $Viewer.Source = $Navigator.CurrentFile.FullName
                        }
                        Path 'images/arrow-left-solid-full.svg'
                    }
                    Button 'ForwardButton' {
                        $this.Width = 75
                        $this.Margin = 5
                        $this.IsEnabled = $False

                        When 'Click' {
                            Write-Host "Forward"
                            $Navigator = (Reference 'Window').Tag.FileNavigator
                            if (-not $Navigator -or -not $Navigator.CurrentFile) { return }
                            $Navigator.MoveNext()
                            $Viewer = Reference 'Viewer'
                            $Viewer.Source = $Navigator.CurrentFile.FullName
                        }
                        Path 'images/arrow-right-solid-full.svg'
                    }
                }
            }
        }
    }
} | Show-WPFWindow
