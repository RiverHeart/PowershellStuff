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
    $self.Title = 'Data Entry Form'
    $self.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $self.TopMost = $True
    $self.Height = 300
    $self.Width = 300

    StackPanel "MainStackPanel" {
        $self.Margin = 5

        Label 'DataEntryLabel' {
            $self.Content = 'Please enter the information in the space below:'
        }
        TextBox "DataEntryBox" {
            $self.HorizontalAlignment = [HorizontalAlignment]::Left
            $self.Width = 260
            $self.Height = 20
        }
        StackPanel 'ButtonPanel' {
            $self.Orientation = [Orientation]::Horizontal

            Button 'OKButton' {
                $self.Content = 'OK'
                $self.Width = 75
                $self.Margin = 5

                Handler 'Click' {
                    $Window = Reference 'Window'
                    $Window.DialogResult = $True
                }
            }
            Button 'CancelButton' {
                $self.Content = 'Cancel'
                $self.Width = 75
                $self.Margin = 5

                Handler 'Click' {
                    $Window = Reference 'Window'
                    $Window.DialogResult = $False
                }
            }
        }
    }
} | Show-WPFWindow

if ($LastDialogResult) {
    Write-Host "Received user input."
    $Result = Select-WPFObject 'DataEntryBox' -Property Text
    $Result
} else {
    Write-Host "User cancelled operation."
}
