Describe 'Shortcut' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = {
            -Shortcut 'Open' {
                Write-Host "This should not execute"
            }
        }

        $Result.Invoke() | Should -BeNullOrEmpty
    }
}
