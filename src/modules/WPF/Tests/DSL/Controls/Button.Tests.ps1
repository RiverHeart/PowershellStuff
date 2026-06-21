Describe 'Button' -Tag 'Button' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $Result = {
            -Button "Button_$Id" {
                $this.Content = "Click me"
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }
}
