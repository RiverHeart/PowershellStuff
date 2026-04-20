using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a custom input box.

.DESCRIPTION
    Creates a custom input box.

    Reimplementation of the Microsoft WinForm example.

.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/samples/creating-a-custom-input-box?view=powershell-7.5
#>

# Change to the script directory if we're not in it.
if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'

Import-Module ../.. -Force

Window 'Window' {
    $this.Title = 'Data Entry Form'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.TopMost = $True
    $this.Height = 300
    $this.Width = 300

    StackPanel "MainStackPanel" {
        $this.Margin = 5

        Label 'DataEntryLabel' {
            $this.Content = 'Please enter the information in the space below:'
        }
        TextBox "DataEntryBox" {
            $this.HorizontalAlignment = [HorizontalAlignment]::Left
            $this.Width = 260
            $this.Height = 20
        }
        StackPanel 'ButtonPanel' {
            $this.Orientation = [Orientation]::Horizontal

            Button 'OKButton' {
                $this.Content = 'OK'
                $this.Width = 75
                $this.Margin = 5

                When 'Click' {
                    $Window = Reference 'Window'
                    $Window.DialogResult = $True
                }
            }
            Button 'CancelButton' {
                $this.Content = 'Cancel'
                $this.Width = 75
                $this.Margin = 5

                When 'Click' {
                    $Window = Reference 'Window'
                    $Window.DialogResult = $False
                }
            }
        }
    }
} | Show-WPFWindow

if ($LastDialogResult) {
    Write-Host "Received user input."
    $Result = Get-WPFRegisteredObject 'DataEntryBox' -Property Text
    $Result
} else {
    Write-Host "User cancelled operation."
}

