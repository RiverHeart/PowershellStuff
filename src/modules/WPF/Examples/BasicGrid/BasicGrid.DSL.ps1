using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a basic grid with rows and columns.

.DESCRIPTION
    Creates a basic grid with rows and columns.
#>

# Change to the script directory if we're not in it.
if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'
$DebugPreference = 'Continue'

Import-Module ../.. -Force

Window 'Window' {
    $self.Title = 'Button Example'
    $self.SizeToContent = 'WidthAndHeight'

    Grid 'Grid' {
        Row {
            Cell {
                Button "EnglishButton" {
                    $self.Content = 'English'
                    $self.Width = 100

                    Handler "Click" {
                        Write-Host "Hello World"
                    }
                }
            }
            Cell {
                Button "JapaneseButton" {
                    $self.Content = 'Japanese'
                    $self.Width = 100

                    Handler "Click" {
                        Write-Host "Konichiwa Sekai"
                    }
                }
            }
        }

        Row {
            Cell {
                Button "SpanishButton" {
                    $self.Content = 'Spanish'
                    $self.Width = 100

                    Handler "Click" {
                        Write-Host "Hola mundo"
                    }
                }
            }
        }
    }
} | Show-WPFWindow
