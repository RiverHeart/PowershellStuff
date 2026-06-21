Describe 'MenuItem' -Tag 'MenuItem' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Menu = [System.Windows.Controls.Menu]::new()

        $Result = {
            -MenuItem "Item_$Id" {
                $this.Header = "File"
            }
        }.Invoke()

        $Menu.Items.Count | Should -Be -ExpectedValue 0
    }
}
