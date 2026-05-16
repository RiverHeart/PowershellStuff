Describe 'MenuItem' -Tag 'MenuItem' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $MenuBar = [System.Windows.Controls.Menu]::new()

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -MenuItem "Item_$Id" {
                $this.Header = "File"
            }
        }.Invoke()

        $MenuBar.Items.Count | Should -Be -ExpectedValue 0
    }
}
