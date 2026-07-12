using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates an animated button.

.DESCRIPTION
    Reimplementation of the animated button from the WPF walkthrough.

.LINK
    https://learn.microsoft.com/en-us/dotnet/desktop/wpf/controls/walkthrough-create-a-button-by-using-xaml
#>

# Change to the script directory if we're not in it.
if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'
$DebugPreference = 'Continue'

Import-Module ../.. -Force

Window 'Window' {
    $this.Title = 'Animated Button'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 900
    $this.Height = 600

    Import .\AnimatedButton.styles.ps1

    StackPanel 'Content' {
        $this.Orientation = 'Vertical'
        $this.HorizontalAlignment = 'Left'

        Button 'Button1' {
            $this.Content = 'Button 1'
            On Click {
                # TODO: event handler
            }
        }
        Button 'Button2' {
            $this.Content = 'Button 2'
            On Click {
                # TODO: event handler
            }
        }
        Button 'Button3' {
            $this.Content = 'Button 3'
            On Click {
                # TODO: event handler
            }
        }
    }

} | Show-WPFWindow
