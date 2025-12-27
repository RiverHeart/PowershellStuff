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
    Properties @{
        Title = 'Data Entry Form'
        WindowStartupLocation = [WindowStartupLocation]::CenterScreen
        TopMost = $True
        Height = 300
        Width = 300
    }
    StackPanel "MainStackPanel" {
        Properties @{
            Margin = 5
        }
        Label 'DataEntryLabel' {
            Properties @{
                Content = 'Please enter the information in the space below:'
            }
        }
        TextBox "DataEntryBox" {
            Properties @{
                HorizontalAlignment = [HorizontalAlignment]::Left
                Width = 260
                Height = 20
            }
        }
        StackPanel 'ButtonPanel' {
            Properties @{
                Orientation = [Orientation]::Horizontal
            }
            Button 'OKButton' {
                Properties @{
                    Content = 'OK'
                    Width = 75
                    Margin = 5
                }
                Handler 'Click' {
                    $Window = Reference 'Window'
                    $Window.DialogResult = $True
                }
                #Path 'arrow-left-solid-full.svg'
            }
            Button 'CancelButton' {
                Properties @{
                    Content = 'Cancel'
                    Width = 75
                    Margin = 5
                }
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
