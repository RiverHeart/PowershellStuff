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
    Properties @{
        Title = 'Select A Date'
        WindowStartupLocation = [WindowStartupLocation]::CenterScreen
        TopMost = $True
        SizetoContent = 'WidthAndHeight'
        Width = 0
        Height = 0
    }

    StackPanel 'RootContainer' {
        Properties @{
            Margin = 5
        }

        DatePicker 'DatePicker' {
            Handler 'SelectedDateChanged' {
                $OKButton = Reference 'OKButton'
                $OKButton.IsEnabled = $True
            }
        }

        StackPanel 'ButtonPanel' {
            Properties @{
                Orientation = [Orientation]::Horizontal
            }
            Button "OKButton" {
                Properties @{
                    Content = 'OK'
                    Width = 75
                    Margin = 5
                    IsEnabled = $False
                }
                Handler "Click" {
                    $Window = Reference 'Window'
                    $Window.DialogResult = $True
                }
            }
            Button "CancelButton" {
                Properties @{
                    Content = 'Cancel'
                    Width = 75
                    Margin = 5
                }
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
