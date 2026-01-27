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
    $self.Title = 'Image Viewer'
    $self.WindowStartupLocation = [WindowStartupLocation]::CenterScreen

    # Window doesn't have a Command property like button so
    # you need to wire up an event.
    When PreviewKeyDown {
        param($sender, $event)
        if ($event.key -ne 'Escape') { return }
        $self.WindowStyle = [WindowStyle]::SingleBorderWindow
        $self.WindowState = [WindowState]::Normal
        $self.ResizeMode = [ResizeMode]::CanResize
    }

    Grid "Body" {
        $self.Margin = 5

        Row {
            Cell 'Expand' {
                MenuBar 'Menu' {
                    $self.Height = 25

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
                            $script:FileNavigator = New-WPFFileNavigator -Path $FileName -Category Image

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

                        # FIXME:
                        # Obvious in hindsight but it seems the closure I was using
                        # to support `$Self` in Add-WPFHandler broke the scriptblock's
                        # ability to access `$Script:` variables, rendering these controls
                        # useless.
                        When 'Click' {
                            Write-Host "Back"
                            if (-not $script:FileNavigator.CurrentFile) { return }
                            $FileNavigator.MovePrevious()
                            $Viewer = Reference 'Viewer'
                            $Viewer.Source = $script:FileNavigator.CurrentFile.FullName
                        }
                        Path 'images/arrow-left-solid-full.svg'
                    }
                    Button 'ForwardButton' {
                        $self.Width = 75
                        $self.Margin = 5
                        $self.IsEnabled = $False

                        When 'Click' {
                            Write-Host "Forward"
                            if (-not $script:FileNavigator.CurrentFile) { return }
                            $script:FileNavigator.MoveNext()
                            $Viewer = Reference 'Viewer'
                            $Viewer.Source = $script:FileNavigator.CurrentFile.FullName
                        }
                        Path 'images/arrow-right-solid-full.svg'
                    }
                }
            }
        }
    }
} | Show-WPFWindow
