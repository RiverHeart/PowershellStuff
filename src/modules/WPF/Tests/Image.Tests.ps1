Describe 'Image' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()
        $PSVars = @([psvariable]::new('this', $Parent))

        $Result = {
            -Image "Image_$Id" {
                $this.Source = "test.png"
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Content | Should -BeNullOrEmpty
    }
}
