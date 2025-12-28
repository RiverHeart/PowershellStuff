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
    Properties @{
        Title = 'Image Viewer'
        WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    }

    StackPanel "Body" {
        Properties @{
            Margin = 5
        }

        DockPanel 'MenuPanel' {
            Menu 'Menu' {
                Properties @{
                    Height = 25
                }

                MenuItem '_File' {
                    MenuItem '_Open' {
                        Handler Click {
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

        # This needs to go in a scroll window or something.
        ScrollViewer 'ScrollViewer' {
            Image 'Viewer' {
                Properties @{
                    Source = $CurrentNode.Value
                    StretchDirection = [StretchDirection]::DownOnly  # Prevent image from stretching across the entire window.
                }
                Handler SourceUpdated {
                    $Viewer = Reference 'Viewer'
                    $Viewer.UpdateLayout()
                }
            }
        }

        StackPanel 'ButtonPanel' {
            Properties @{
                Orientation = [Orientation]::Horizontal
                HorizontalAlignment = [HorizontalAlignment]::Center
            }
            Button 'BackButton' {
                Properties @{
                    Width = 75
                    Margin = 5
                }
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
                Properties @{
                    Width = 75
                    Margin = 5
                }
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
