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

function Invoke-ImageViewerToggleTheme {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    Toggle-WPFTheme -Root $Window
}

function Invoke-ImageViewerUpdateStatus {
    [CmdletBinding()]
    param()

    $State = (Reference 'Window').Tag
    $FileLabel = Reference 'StatusFileLabel'
    $IndexLabel = Reference 'StatusIndexLabel'
    $DetailsLabel = Reference 'StatusDetailsLabel'
    $ZoomLabel = Reference 'StatusZoomLabel'

    if (-not $State.IsFileLoaded -or -not $State.FileNavigator -or -not $State.FileNavigator.CurrentFile) {
        $FileLabel.Content = 'No image loaded'
        $IndexLabel.Content = '0/0'
        $DetailsLabel.Content = '-'
        $ZoomLabel.Content = '100%'
        return
    }

    $CurrentFile = $State.FileNavigator.CurrentFile
    $CurrentIndex = $State.FileNavigator.Index + 1
    $TotalFiles = $State.FileNavigator.Files.Count
    $Source = (Reference 'Viewer').Source

    $Dimensions = '-'
    if ($Source -is [System.Windows.Media.Imaging.BitmapSource]) {
        $Dimensions = "$($Source.PixelWidth)x$($Source.PixelHeight)"
    }

    $ZoomPercent = [Math]::Round([double] $State.ZoomLevel * 100)

    $FileLabel.Content = $CurrentFile.Name
    $IndexLabel.Content = "$CurrentIndex/$TotalFiles"
    $DetailsLabel.Content = $Dimensions
    $ZoomLabel.Content = "$ZoomPercent%"
}

function Invoke-ImageViewerSetZoom {
    [CmdletBinding()]
    param(
        [double] $Delta = 0,

        [switch] $Reset
    )

    $State = (Reference 'Window').Tag
    $Viewer = Reference 'Viewer'

    $ZoomLevel = if ($Reset) { 1.0 } else { [double] $State.ZoomLevel + $Delta }
    $ZoomLevel = [Math]::Max(0.10, [Math]::Min(8.00, $ZoomLevel))
    $ZoomLevel = [Math]::Round($ZoomLevel, 2)
    $State.ZoomLevel = $ZoomLevel

    if (-not ($Viewer.LayoutTransform -is [ScaleTransform])) {
        $Viewer.LayoutTransform = [ScaleTransform]::new(1.0, 1.0)
    }

    $Transform = [ScaleTransform] $Viewer.LayoutTransform
    $Transform.ScaleX = $ZoomLevel
    $Transform.ScaleY = $ZoomLevel

    Invoke-ImageViewerUpdateStatus
}

function Invoke-ImageViewerLoadFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $FileName
    )

    if (-not (Test-Path -Path $FileName -PathType Leaf)) {
        Write-Warning "File not found: '$FileName'"
        return
    }

    $Window = Reference 'Window'
    $Viewer = Reference 'Viewer'

    try {
        $Viewer.Source = $FileName

        $State = $Window.Tag
        $State.FileNavigator = New-WPFFileNavigator -Path $FileName -Category Image
        $State.IsFileLoaded = $true

        Invoke-ImageViewerSetZoom -Reset
        Invoke-ImageViewerUpdateStatus
    } catch {
        Write-Warning "Failed to load image '$FileName': $_"
    }
}

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
    Invoke-ImageViewerUpdateStatus
}

# Define the Image Viewer GUI

. "$PSScriptRoot/ImageViewer.Styles.ps1"

Window 'Window' {
    $this.Title = 'Image Viewer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.AllowDrop = $true
    $this.Tag = New-WPFObservableState @{
        IsFullScreen   = $false
        IsFileLoaded   = $false
        ZoomLevel      = 1.0
        OldWindowStyle = [WindowStyle]::SingleBorderWindow
        OldWindowState = [WindowState]::Normal
        OldResizeMode  = [ResizeMode]::CanResize
        CurrentTheme   = if (Get-WPFDarkModePreference) { 'Dark' } else { 'Light' }
        FileNavigator  = $null
    }

    Use-WPFTheme -Name $this.Tag.CurrentTheme -Root $this

    # Window doesn't have a Command property like button so
    # you need to wire up an event.
    When KeyDown {
        param($sender, $event)

        switch ($event.Key) {
            'Escape' {
                $State = $this.Tag
                if (-not $State.IsFullScreen) { return }

                Set-WPFWindowFullScreen -IsFullScreen $False
                $event.Handled = $True
                break
            }
            'F11' {
                $State = $this.Tag
                Set-WPFWindowFullScreen -IsFullScreen (-not $State.IsFullScreen)
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
        $event = $args[1]

        if ($event.Data.GetDataPresent([DataFormats]::FileDrop)) {
            $event.Effects = [DragDropEffects]::Copy
        } else {
            $event.Effects = [DragDropEffects]::None
        }

        $event.Handled = $true
    }

    When Drop {
        $event = $args[1]

        if (-not $event.Data.GetDataPresent([DataFormats]::FileDrop)) {
            return
        }

        $Files = [string[]] $event.Data.GetData([DataFormats]::FileDrop)
        if ($Files.Count -gt 0) {
            Invoke-ImageViewerLoadFile -FileName $Files[0]
        }

        $event.Handled = $true
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

                            Invoke-ImageViewerLoadFile -FileName $FileName
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
                            Set-WPFWindowFullScreen -IsFullScreen (-not $State.IsFullScreen)
                        }
                    }

                    MenuItem '(V)iew/(T)oggle Theme' {
                        Shortcut 'ToggleTheme' 'Ctrl+T' {
                            Invoke-ImageViewerToggleTheme
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

        Row 'Expand' {
            Column {
                # In case the image is larger than the window, use the ScrollViewer
                # to adjust the view window.
                ScrollViewer 'ScrollViewer' {
                    $this.VerticalScrollbarVisibility = [ScrollBarVisibility]::Auto
                    $this.HorizontalScrollbarVisibility = [ScrollBarVisibility]::Auto

                    When PreviewMouseWheel {
                        $event = $args[1]

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

        Row {
            Column {
                # TODO:
                # * Needs to support Counter/Clockwise rotation.
                # * Needs to support "Fit to Window" and "Actual Image Size" modes.
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

        # Row {
        #     Column 'Expand' {
        #         DockPanel 'StatusPanel' {
        #             $this.Margin = 5, 0, 5, 0
        #             Bind Visibility Window.Tag.IsFullScreen -Invert

        #             Label 'StatusFileLabel' {
        #                 $this.Content = 'No image loaded'
        #                 [DockPanel]::SetDock($this, [Dock]::Left)
        #             }
        #             Label 'StatusIndexLabel' {
        #                 $this.Content = '0/0'
        #                 [DockPanel]::SetDock($this, [Dock]::Right)
        #             }
        #             Label 'StatusDetailsLabel' {
        #                 $this.Content = '-'
        #                 [DockPanel]::SetDock($this, [Dock]::Right)
        #             }
        #             Label 'StatusZoomLabel' {
        #                 $this.Content = '100%'
        #                 [DockPanel]::SetDock($this, [Dock]::Right)
        #             }
        #         }
        #     }
        # }
    }

    Invoke-ImageViewerUpdateStatus
} | Show-WPFWindow
