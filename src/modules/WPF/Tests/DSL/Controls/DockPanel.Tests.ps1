Describe 'DockPanel' -Tag 'DockPanel' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $Result = {
            -DockPanel "Panel_$Id" {
                Label "Child_$Id" {}
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }
}
