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

Window 'Window' {
    $this.Title = 'Image Viewer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.AllowDrop = $true
    $this.WindowState = [WindowState]::Maximized
    $this.Tag = New-WPFObservableState @{
        IsFullScreen  = $false
        IsFileLoaded  = $false
        IsFitMode     = $true
        ZoomLevel     = 1.0
        RotationAngle = 0
        CurrentTheme  = if (Get-WPFDarkModePreference) { 'Dark' } else { 'Light' }
        FileNavigator = $null
    }

    Use-WPFTheme -Name $this.Tag.CurrentTheme -Root $this

    When KeyDown {
        param($sender, $event)

        switch ($event.Key) {
            'Escape' {
                if ((Reference 'Window').Tag.IsFullScreen) {
                    Set-WPFWindowFullScreen -IsFullScreen $false
                    Invoke-ImageViewerFitToWindow
                    $event.Handled = $true
                }
            }
            'Left' {
                Invoke-ImageViewerNavigate -Direction Back
                $event.Handled = $true
            }
            { $_ -in @('Right', 'Space') } {
                Invoke-ImageViewerNavigate -Direction Forward
                $event.Handled = $true
            }
        }
    }

    Grid 'Body' {
        Row {
            Column 'Expand' {
                MenuBar 'Menu' {
                    Watch Visibility Window.Tag.IsFullScreen -Invert

                    MenuItem '(F)ile/(O)pen' {
                        Shortcut 'Open' {
                            $fileName = Get-WPFFileSelection -Category Image -Window (Reference 'Window')
                            if ($fileName) {
                                Invoke-ImageViewerLoadFile -FileName $fileName
                            }
                        }
                    }
                }
            }
        }

        Row 'Expand' {
            Column {
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
    }
} | Show-WPFWindow
