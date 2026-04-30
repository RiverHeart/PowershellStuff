Describe 'Menu' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()
        $PSVars = @([psvariable]::new('this', $Parent))

        $Result = {
            -Menu "Menu_$Id" {
                MenuItem "File_$Id" {}
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Content | Should -BeNullOrEmpty
    }
}
