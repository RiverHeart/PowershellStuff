Describe 'MenuItem' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $MenuBar = [System.Windows.Controls.Menu]::new()
        $PSVars = @([psvariable]::new('this', $MenuBar))

        $Result = {
            -MenuItem "Item_$Id" {
                $this.Header = "File"
            }
        }.InvokeWithContext($null, $PSVars)

        $MenuBar.Items.Count | Should -Be -ExpectedValue 0
    }
}
