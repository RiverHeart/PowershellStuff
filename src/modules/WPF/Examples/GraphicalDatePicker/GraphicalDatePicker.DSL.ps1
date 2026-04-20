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
    $this.Title = 'Select A Date'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.TopMost = $True
    $this.SizetoContent = 'WidthAndHeight'
    $this.Width = 0
    $this.Height = 0

    StackPanel 'RootContainer' {
        $this.Margin = 5

        DatePicker 'DatePicker' {
            When 'SelectedDateChanged' {
                (Reference 'OKButton').IsEnabled = $True
            }
        }

        StackPanel 'ButtonPanel' {
            $this.Orientation = [Orientation]::Horizontal

            Button "OKButton" {
                $this.Content = 'OK'
                $this.Width = 75
                $this.Margin = 5
                $this.IsEnabled = $False

                When "Click" {
                    (Reference 'Window').DialogResult = $True
                }
            }
            Button "CancelButton" {
                $this.Content = 'Cancel'
                $this.Width = 75
                $this.Margin = 5

                When "Click" {
                    (Reference 'Window').DialogResult = $False
                }
            }
        }
    }
} | Show-WPFWindow

if ($LastDialogResult) {
    Write-Host "Received user input."
    $Date = Get-WPFRegisteredObject 'DatePicker' -Property SelectedDate
    Write-Host "Date selected: $($Date.ToShortDateString())"
} else {
    Write-Host "User cancelled operation."
}

