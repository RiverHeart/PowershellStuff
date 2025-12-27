using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Media

<#
.SYNOPSIS
    Creates a custom input box.

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

# Get images from current directory and convert to a linked
# list to simplify looping back around to the first image
# when we reach the end.
$ImageLinkedList = [System.Collections.Generic.LinkedList[String]]::new()
Get-ChildItem -Path $PWD |
    Where-Object { $_.Extension -in @('.jpg', '.png', '.bmp', '.gif', '.tiff', '.ico') } |
    ForEach-Object {
        $ImageLinkedList.AddLast($_)
    }

# Ensure there are images to display.
# TODO: Should probably make it so that there's a default
# image of nothing at all so user can select an image or folder
# from the title bar.
if ($ImageLinkedList.Count -le 0) {
    Write-Error "No images found"
    return
}

# CurrentNode will be used to initialize the Image
# and be updated by the buttons to get the previous/next
# image to display.
$CurrentNode = $ImageLinkedList.First

# Define the Image Viewer GUI
Window 'Window' {
    Properties @{
        Title = 'Image Viewer'
        WindowStartupLocation = [WindowStartupLocation]::CenterScreen
        TopMost = $True
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
                    MenuItem '_Open' {}
                    MenuItem '_Exit' {
                        Handler Click {
                            $Window = Reference 'Window'
                            $Window.Close()
                        }
                    }
                }
                MenuItem '_Help' {
                    MenuItem '_About' {}
                }
            }
        }

        Image 'Viewer' {
            Properties @{
                Source = $CurrentNode.Value
                StretchDirection = [StretchDirection]::DownOnly  # Prevent image from stretching across the entire window.
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
                    $CurrentNode.Previous
                    $Viewer = Reference 'Viewer'
                    $Viewer.Source = $CurrentNode.Value
                }
                Path 'images/arrow-left-solid-full.svg'
            }
            Button 'ForwardButton' {
                Properties @{
                    Width = 75
                    Margin = 5
                }
                Handler 'Click' {
                    $CurrentNode.Next
                    $Viewer = Reference 'Viewer'
                    $Viewer.Source = $CurrentNode.Value
                }
                Path 'images/arrow-right-solid-full.svg'
            }
        }
    }
} | Show-WPFWindow
