Describe 'Image' -Tag 'Image' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $Result = {
            -Image "Image_$Id" {
                $this.Source = "test.png"
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }
}
