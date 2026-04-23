using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Minimal example for themes and styles.

.DESCRIPTION
    Demonstrates:

    - Theme and Brush definitions
    - Implicit target-type styles
    - Named style overrides with UseStyle
    - Runtime Light/Dark toggling
#>

if ($PSScriptRoot -and $PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'

Import-Module ../.. -Force

function Set-ExampleTheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Light', 'Dark')]
        [string] $Name
    )

    $Window = Reference 'Window'
    Use-WPFTheme -Name $Name -Root $Window

    $Window.Tag.CurrentTheme = $Name
    (Reference 'ThemeLabel').Content = "Theme: $Name"
    (Reference 'ToggleThemeButton').Content = if ($Name -eq 'Dark') {
        'Switch to Light'
    } else {
        'Switch to Dark'
    }
}

function Toggle-ExampleTheme {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    $nextTheme = if ($Window.Tag.CurrentTheme -eq 'Dark') { 'Light' } else { 'Dark' }
    Set-ExampleTheme -Name $nextTheme
}

Theme 'Light' {
    Brush 'WindowBackground' '#FFFFFF'
    Brush 'Foreground' '#111111'
    Brush 'ButtonBackground' '#ECECEC'
}

Theme 'Dark' {
    Brush 'WindowBackground' '#1E1E1E'
    Brush 'Foreground' '#F0F0F0'
    Brush 'ButtonBackground' '#2A2A2A'
}

# Implicit styles
Style Window {
    Setter Background WindowBackground -Resource
    Setter Foreground Foreground -Resource
}

Style Label {
    Setter Foreground Foreground -Resource
}

Style Button {
    Setter Background ButtonBackground -Resource
    Setter Foreground Foreground -Resource
    Setter Margin '0,8,0,0'
}

# Named style override
Style 'PrimaryButton' Button {
    Setter Background ButtonBackground -Resource
    Setter Foreground Foreground -Resource
    Setter FontWeight ([System.Windows.FontWeights]::SemiBold)
    Setter Padding '14,6,14,6'
    Setter Margin '0,12,0,0'
}

Window 'Window' {
    $this.Title = 'Theme + Style Demo'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Tag = New-WPFObservableState @{
        CurrentTheme = if (Get-WPFDarkModePreference) { 'Dark' } else { 'Light' }
    }

    StackPanel 'Layout' {
        $this.Margin = 20

        Label 'TitleLabel' {
            $this.FontSize = 22
            $this.Content = 'Minimal Theme + Style Example'
        }

        Label 'ThemeLabel' {
            $this.FontSize = 14
            $this.Content = 'Theme:'
        }

        Button 'ToggleThemeButton' {
            UseStyle 'PrimaryButton'
            $this.Content = 'Toggle Theme'
            When Click {
                Toggle-ExampleTheme
            }
        }
    }

    When Loaded {
        Set-ExampleTheme -Name $this.Tag.CurrentTheme
    }
} | Show-WPFWindow
