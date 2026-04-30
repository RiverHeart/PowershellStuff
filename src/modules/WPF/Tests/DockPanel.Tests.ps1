Describe 'DockPanel' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()
        $PSVars = @([psvariable]::new('this', $Parent))

        $Result = {
            -DockPanel "Panel_$Id" {
                Label "Child_$Id" {}
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Content | Should -BeNullOrEmpty
    }
}
