Describe 'TextBlock' -Tag 'TextBlock' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $Result = {
            -TextBlock "TextBlock_$Id" {
                $this.Text = "Hello"
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }
}
