<#
.SYNOPSIS
    Creates a window with a stackpanel and a couple buttons.
#>

# Change to the script directory if we're not in it.
if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'

Import-Module ../.. -Force

Window 'Window' {
    $self.Title = 'Button Example'
    $self.Height = 100
    $self.Width = 250

    StackPanel "Buttons" {
        Button "EnglishButton" {
            $self.Content = 'English'
            $self.Width = 100

            When "Click" {
                Write-Host "Hello World! I speak $($Self.Content)"
            }
        }
        Button "JapaneseButton" {
            $self.Content = 'Japanese'
            $self.Width = 100

            When "Click" {
                Write-Host "Konichiwa Sekai! I speak $($Self.Content)"
            }
        }
    }
} | Show-WPFWindow
