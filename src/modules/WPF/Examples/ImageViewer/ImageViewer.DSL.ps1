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

Import-Module ../.. -Force

# Define the Image Viewer GUI
Window 'Window' {
    $self.Title = 'Image Viewer'
    $self.WindowStartupLocation = [WindowStartupLocation]::CenterScreen

    # Window doesn't have a Command property like button so
    # you need to wire up an event.
    Handler PreviewKeyDown {
        param($sender, $event)
        if ($event.key -ne 'Escape') { return }
        $Window = Reference 'Window'
        $Window.WindowStyle = [WindowStyle]::SingleBorderWindow
        $Window.WindowState = [WindowState]::Normal
        $Window.ResizeMode = [ResizeMode]::CanResize
    }

    Grid "Body" {
        $self.Margin = 5

        Row {
            # Wildcard indicates this column takes all horizontal space.
            Cell 'Expand' {
                MenuBar 'Menu' {
                    $self.Height = 25

                    MenuItem '(F)ile/(O)pen' {
                        Handler Click {
                            $Window = Reference 'Window'
                            $FileName = Get-WPFFileSelection -Type All -Category Image -Window $Window

                            # Return early if we failed to get a file
                            if (-not $FileName) {
                                return
                            }

                            $Viewer = Reference 'Viewer'
                            $Viewer.Source = $FileName
                            $script:FileNavigator = New-WPFFileNavigator -Path $FileName -Category Image

                            # Enable buttons
                            (Reference 'ForwardButton').IsEnabled = $True
                            (Reference 'BackButton').IsEnabled = $True
                        }
                    }
                    MenuItem '(F)ile/(E)xit' {
                        Shortcut 'CloseCommand' 'Ctrl+q' {
                            $Window = Reference 'Window'
                            $Window.Close()
                        }
                    }

                    MenuItem '(V)iew/FullScreen' {
                        Shortcut 'FullScreenCommand' 'F11' {
                            $Window = Reference 'Window'
                            if ($Window.WindowState -eq [WindowState]::Maximized) {
                                $Window.WindowStyle = [WindowStyle]::SingleBorderWindow
                                $Window.WindowState = [WindowState]::Normal
                                $Window.ResizeMode = [ResizeMode]::CanResize
                            } else {
                                $Window.WindowStyle = [WindowStyle]::None
                                $Window.WindowState = [WindowState]::Maximized
                                $Window.ResizeMode = [ResizeMode]::NoResize
                            }
                        }
                    }

                    MenuItem '(H)elp/(A)bout' {
                        Shortcut 'AboutCommand' 'Ctrl+A' {
                            Write-Host 'Implement Me'
                        }
                    }
                }
            }
        }

        # Wildcard indicates this row takes all available vertical space;
        # which is useful because this row should be as large as possible to
        # display the image.
        Row 'Expand' {
            Cell {
                # In case the image is larger than the window, use the ScrollViewer
                # to adjust the view window.
                ScrollViewer 'ScrollViewer' {
                    $self.VerticalScrollbarVisibility = [ScrollBarVisibility]::Auto
                    $self.HorizontalScrollbarVisibility = [ScrollBarVisibility]::Auto

                    Image 'Viewer' {
                        $self.VerticalAlignment = [VerticalAlignment]::Center  # Center image to mirror how most image viewers work.
                        $self.StretchDirection = [StretchDirection]::DownOnly  # Prevent image from stretching across the entire window.
                    }
                }
            }
        }

        Row {
            Cell {
                # TODO:
                # * Needs to support Counter/Clockwise rotation.
                # * Needs to support "Fit to Window" and "Actual Image Size"
                # * Needs to support arrow key/spacebar movement
                StackPanel 'ButtonPanel' {
                    $self.Orientation = [Orientation]::Horizontal
                    $self.HorizontalAlignment = [HorizontalAlignment]::Center

                    Button 'BackButton' {
                        $self.Width = 75
                        $self.Margin = 5
                        $self.IsEnabled = $False

                        Handler 'Click' {
                            if (-not $script:FileNavigator.CurrentFile) { return }
                            $FileNavigator.MovePrevious()
                            $Viewer = Reference 'Viewer'
                            $Viewer.Source = $script:FileNavigator.CurrentFile.FullName
                            Write-Host "Back"
                        }
                        Path 'images/arrow-left-solid-full.svg'
                    }
                    Button 'ForwardButton' {
                        $self.Width = 75
                        $self.Margin = 5
                        $self.IsEnabled = $False

                        Handler 'Click' {
                            if (-not $script:FileNavigator.CurrentFile) { return }
                            $script:FileNavigator.MoveNext()
                            $Viewer = Reference 'Viewer'
                            $Viewer.Source = $script:FileNavigator.CurrentFile.FullName
                            Write-Host "Forward"
                        }
                        Path 'images/arrow-right-solid-full.svg'
                    }
                }
            }
        }
    }
} | Show-WPFWindow
