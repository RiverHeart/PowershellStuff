Describe 'DatePicker' -Tag 'DatePicker' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -DatePicker "DatePicker_$Id" {
                $this.SelectedDate = [DateTime]::Now
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }
}
