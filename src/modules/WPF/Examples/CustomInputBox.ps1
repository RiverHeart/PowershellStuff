if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'

Import-Module ../ -Force

$Result = Window "Data Entry Form" 300 200 {
    Properties @{
        WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        TopMost = $True
    }
    StackPanel "MainStackPanel" {
        Button "OKButton" "OK" {
            Properties @{
                Width = 75
                Height = 23
            }
            Handler "Click" {
                # NOTE: GetWindow() doesn't exist. Need to find another way
                $this.GetWindow().DialogResult = $True
            }
        }
        Button "CancelButton" "Cancel" {
            Properties @{
                Width = 75
                Height = 23
            }
            Handler "Click" {
                # NOTE: GetWindow() doesn't exist. Need to find another way
                $this.GetWindow().DialogResult = $False
            }
        }
        Label 'DataEntryLabel' {
            Properties @{
                Width = 280
                Height = 20
                Text = 'Please enter the information in the space below:'
            }
        }
        TextBox "DataEntryBox" {
            Properties @{
                Width = 260
                Height = 20
            }
        }
    }
} | Show-WPFWindow
