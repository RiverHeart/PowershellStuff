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

    Grid "Body" {
        $self.Margin = 5

        Row {
            # Wildcard indicates this column takes all horizontal space.
            Cell 'Expand' {

                # TODO: Create an abstraction called MenuBar
                # The DockPanel wrapper is just an annoying implementation detail.
                DockPanel 'MenuPanel' {
                    Menu 'Menu' {
                        $self.Height = 25

                        MenuItem '_File' {
                            MenuItem '_Open' {
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
                            MenuItem '_Exit' {
                                Handler Click {
                                    $Window = Reference 'Window'
                                    $Window.Close()
                                }
                            }
                        }

                        MenuItem '_Help' {
                            MenuItem '_About' {
                                # Bad example of using RelayCommand. Really need something that makes
                                # use of the CanExecute part.
                                RelayCommand {
                                    Write-Host 'Implement Me'
                                }
                            }
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
