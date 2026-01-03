using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a custom input box.

.DESCRIPTION
    Creates a custom input box.

    Reimplementation of the Microsoft WinForm example.

.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/samples/creating-a-graphical-date-picker?view=powershell-7.5
#>

# Change to the script directory if we're not in it.
if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'
$DebugPreference = 'Continue'

Import-Module ../.. -Force

Window 'Window' {
    $self.Title = 'Select A Date'
    $self.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $self.TopMost = $True
    $self.SizetoContent = 'WidthAndHeight'
    $self.Width = 0
    $self.Height = 0

    StackPanel 'RootContainer' {
        $self.Margin = 5

        DatePicker 'DatePicker' {
            Handler 'SelectedDateChanged' {
                $OKButton = Reference 'OKButton'
                $OKButton.IsEnabled = $True
            }
        }

        StackPanel 'ButtonPanel' {
            $self.Orientation = [Orientation]::Horizontal

            Button "OKButton" {
                $self.Content = 'OK'
                $self.Width = 75
                $self.Margin = 5
                $self.IsEnabled = $False

                Handler "Click" {
                    $Window = Reference 'Window'
                    $Window.DialogResult = $True
                }
            }
            Button "CancelButton" {
                $self.Content = 'Cancel'
                $self.Width = 75
                $self.Margin = 5

                Handler "Click" {
                    $Window = Reference 'Window'
                    $Window.DialogResult = $False
                }
            }
        }
    }
} | Show-WPFWindow

if ($LastDialogResult) {
    Write-Host "Received user input."
    $Date = Select-WPFObject 'DatePicker' -Property SelectedDate
    Write-Host "Date selected: $($Date.ToShortDateString())"
} else {
    Write-Host "User cancelled operation."
}
