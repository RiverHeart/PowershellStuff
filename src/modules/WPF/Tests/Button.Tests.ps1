Describe 'Button' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()
        $PSVars = @([psvariable]::new('this', $Parent))

        $Result = {
            -Button "Button_$Id" {
                $this.Content = "Click me"
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Content | Should -BeNullOrEmpty
    }
}
