Describe 'Shortcut' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -Shortcut 'Open' {
                Write-Host "This should not execute"
            }
        }

        $Result.Invoke() | Should -BeNullOrEmpty
    }
}
