using namespace Microsoft
using namespace System.Collections.Generic
using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Input
using namespace System.Windows.Media

# Change to the script directory if we're not in it.
if ($PSScriptRoot -and $PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'
$DebugPreference = 'Continue'

Import-Module ../.. -Force

Import "../ImageViewer/ImageViewer.styles.ps1"
Import "../ImageViewer/functions"

App 'Window' {
    $this.Title = 'Image Viewer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.AllowDrop = $true
    $this.WindowState = [WindowState]::Maximized
    State @{
        IsFullScreen = $false
        IsFileLoaded = $false
        IsFitMode = $true
        ZoomLevel = 1.0
        RotationAngle = 0

        CurrentTheme = if (Get-WPFDarkModePreference) { 'Dark' } else { 'Light' }
        FileNavigator = $null
    }

    Use-WPFTheme -Name $this.Tag.CurrentTheme -Root $this

    Key 'Escape' {
        if (-not $this.Tag.IsFullScreen) {
            return
        }

        Set-WPFWindowFullScreen -IsFullScreen $false
        if ($this.Tag.IsFitMode) {
            Invoke-ImageViewerFitToWindow
        }
        $event.Handled = $true
    }

    # Use PreviewKeyDown so navigation still works when focused controls handle KeyDown internally.
    When PreviewKeyDown {
        param($sender, $event)

        switch ($event.Key) {
            'Left' {
                if (Test-ImageViewerShouldNavigate) {
                    Invoke-ImageViewerNavigate -Direction Back
                    $event.Handled = $true
                }
                break
            }
            { $_ -in @('Right', 'Space') } {
                if ($event.Key -eq [System.Windows.Input.Key]::Space -or (Test-ImageViewerShouldNavigate)) {
                    Invoke-ImageViewerNavigate -Direction Forward
                    $event.Handled = $true
                }
                break
            }
        }
    }

    Menu 'Menu' {
        $this.Height = 25
        Bind Visibility -To Window.Tag.IsFullScreen -Invert

        MenuItem '(F)ile/(O)pen' {
            Command 'Open' {
                $Window = Get-WPFWindow
                $FileName = Get-WPFFileSelection -Category Image -Window $Window

                if (-not $FileName) {
                    return
                }

                Invoke-ImageViewerLoadFile -FileName $FileName
            }
        }

        MenuItem '(V)iew/(F)ullScreen' {
            Command 'FullScreen' 'F11' {
                $Window = Get-WPFWindow
                $State = $Window.Tag
                $IsEnteringFullScreen = -not $State.IsFullScreen

                Set-WPFWindowFullScreen -IsFullScreen $IsEnteringFullScreen

                if ($State.IsFitMode) {
                    Invoke-ImageViewerFitToWindow
                }
            }
        }
    }

    Content {
        DockPanel 'MainPanel' {
            $this.LastChildFill = $true

            ScrollViewer 'ScrollViewer' {
                $this.VerticalScrollbarVisibility = [ScrollBarVisibility]::Auto
                $this.HorizontalScrollbarVisibility = [ScrollBarVisibility]::Auto
                $this.Background = 'Transparent'

                Image 'Viewer' {
                    $this.VerticalAlignment = [VerticalAlignment]::Center
                    $this.StretchDirection = [StretchDirection]::DownOnly
                }
            }
        }
    }

    Footer {
        StackPanel 'ButtonPanel' {
            $this.Orientation = [Orientation]::Horizontal
            $this.HorizontalAlignment = [HorizontalAlignment]::Center
            Bind Visibility -To Window.Tag.IsFullScreen -Invert

            Button 'BackButton' {
                Bind IsEnabled -To Window.Tag.IsFileLoaded
                When 'Click' { Invoke-ImageViewerNavigate -Direction Back }
            }

            Button 'ForwardButton' {
                Bind IsEnabled -To Window.Tag.IsFileLoaded
                When 'Click' { Invoke-ImageViewerNavigate -Direction Forward }
            }
        }
    }

    StatusBar {
        Bind Visibility -To Window.Tag.IsFullScreen -Invert

        StatusBarItem 'StatusFileItem' {
            Label 'StatusFileLabel' {
                $this.Content = 'No image loaded'
            }
        }

        StatusBarItem 'StatusZoomItem' {
            Label 'StatusZoomLabel' {
                $this.Content = '100%'
            }
        }
    }
} | Show-WPFWindow
