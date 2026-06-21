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
    $this.Title = 'Button Example'
    $this.Height = 100
    $this.Width = 250

    StackPanel "Buttons" {
        Button "EnglishButton" {
            $this.Content = 'English'
            $this.Width = 100

            On "Click" {
                Write-Host "Hello World! I speak $($this.Content)"
            }
        }
        Button "JapaneseButton" {
            $this.Content = 'Japanese'
            $this.Width = 100

            On "Click" {
                Write-Host "Konichiwa Sekai! I speak $($this.Content)"
            }
        }
    }
} | Show-WPFWindow

