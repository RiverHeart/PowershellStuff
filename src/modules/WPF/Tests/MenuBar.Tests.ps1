Describe 'MenuBar' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()
        $PSVars = @([psvariable]::new('this', $Parent))

        $Result = {
            -MenuBar "MenuBar_$Id" {
                MenuItem "File_$Id" {}
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Content | Should -BeNullOrEmpty
    }
}
