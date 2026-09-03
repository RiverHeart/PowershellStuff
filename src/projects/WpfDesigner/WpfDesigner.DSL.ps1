using namespace System.Windows

<#
.SYNOPSIS
    Entry point for the WPF Designer project.
#>

if ($PWD -ne $PSScriptRoot) {
    Set-Location -Path $PSScriptRoot
}

if (-not (Get-Module -Name WPF)) {
    Import-Module "$PSScriptRoot/../../modules/WPF" -ErrorAction Stop -Force
}

App 'Window' {
    $this.Title = 'WPF Designer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700

    Content {
        # Placeholder until the toolbar/viewport/property panel are built out.
        TextBlock 'PlaceholderText' {
            $this.Margin = 16
            $this.Text = 'WPF Designer scaffold. Toolbar, viewport, and property panel coming in later phases.'
        }
    }
} | Show-WPFWindow
