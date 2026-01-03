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

$CurrentNode = $null

# Define the Image Viewer GUI
Window 'Window' {
    $self.Title = 'Image Viewer'
    $self.WindowStartupLocation = [WindowStartupLocation]::CenterScreen

    StackPanel "Body" {
        $self.Margin = 5

        DockPanel 'MenuPanel' {
            Menu 'Menu' {
                $self.Height = 25

                MenuItem '_File' {
                    MenuItem '_Open' {
                        Handler Click {
                            # TODO: Abstract some of this stuff.
                            $OpenFileDialog = [Microsoft.Win32.OpenFileDialog]::new()
                            $OpenFileDialog.Filter = @(
                                'Image Files (*.jpg;*.png;*.bmp;*.ico;*.tiff;*.gif)|*.jpg;*.png;*.bmp;*.ico;*.tiff;*.gif'
                                'All Files (*.*)|*.*'
                            ) -join '|'

                            if ($OpenFileDialog.ShowDialog() -eq $True) {
                                $Viewer = Reference 'Viewer'
                                $FileName = $OpenFileDialog.FileName
                                $Viewer.Source = $FileName
                                $script:LinkedList = [LinkedList[String]]::new()

                                $ParentDir = $FileName | Split-Path -Parent

                                # Create a linked list that we can easily traverse backwards
                                # and forwards. AddLast() returns a LinkedListNode so use
                                # a Where clause at the end to get a reference to the current
                                # node.
                                $script:CurrentNode = Get-ChildItem -Path $ParentDir |
                                    Where-Object { $_.Extension -in @('.jpg', '.png', '.bmp', '.gif', '.tiff', '.ico') } |
                                    ForEach-Object {
                                        $script:LinkedList.AddLast($_)
                                    } |
                                    Where-Object { $_.Value -eq $FileName }
                            }
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
                        Handler Click {
                            Write-Host "Implement me"
                        }
                    }
                }
            }
        }

        # TODO: This whole section needs to
        # * Be centered in the window
        # * Fill all content between the Menu and Button panels
        ScrollViewer 'ScrollViewer' {
            Image 'Viewer' {
                $self.StretchDirection = [StretchDirection]::DownOnly  # Prevent image from stretching across the entire window.

                Handler SourceUpdated {
                    $Viewer = Reference 'Viewer'
                    $Viewer.UpdateLayout()
                }
            }
        }

        # TODO:
        # * This needs to stick to the bottom of the page. DockPanel didn't
        # seem to work.
        # * Needs to support Counter/Clockwise rotation.
        # * Needs to support "Fit to Window" and "Actual Image Size"
        StackPanel 'ButtonPanel' {
            $self.Orientation = [Orientation]::Horizontal
            $self.HorizontalAlignment = [HorizontalAlignment]::Center

            Button 'BackButton' {
                $self.Width = 75
                $self.Margin = 5

                Handler 'Click' {
                    if (-not $script:CurrentNode) { return }
                    $script:CurrentNode = $script:CurrentNode.Previous
                    $Viewer = Reference 'Viewer'
                    $Viewer.Source = $script:CurrentNode.Value
                    Write-Host "Back"
                }
                Path 'images/arrow-left-solid-full.svg'
            }
            Button 'ForwardButton' {
                $self.Width = 75
                $self.Margin = 5

                Handler 'Click' {
                    if (-not $script:CurrentNode) { return }
                    $script:CurrentNode = $script:CurrentNode.Next
                    $Viewer = Reference 'Viewer'
                    $Viewer.Source = $script:CurrentNode.Value
                    Write-Host "Forward"
                }
                Path 'images/arrow-right-solid-full.svg'
            }
        }
    }
} | Show-WPFWindow
