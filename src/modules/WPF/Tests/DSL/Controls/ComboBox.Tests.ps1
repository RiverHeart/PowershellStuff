Describe 'ComboBox' -Tag 'ComboBox' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -ComboBox 'MyComboBox' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create and configure a ComboBox with the given name' {
        $Id = [guid]::NewGuid().ToString('N')
        $Items = @('Bulbasaur', 'Charmander', 'Squirtle')

        $Result = ComboBox "ComboBox_$Id" {
            $this.ItemsSource = $Items
            $this.SelectedItem = 'Charmander'
        }

        $Result | Should -BeOfType [System.Windows.Controls.ComboBox]
        $Result.Name | Should -Be "ComboBox_$Id"
        @($Result.ItemsSource) | Should -Be $Items
        $Result.SelectedItem | Should -Be 'Charmander'
    }

    It 'Should auto-attach to parent context and return no output' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.StackPanel]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            ComboBox "ComboBox_$Id" {}
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be 0
        $Parent.Children | Should -HaveCount 1
        $Parent.Children[0] | Should -BeOfType [System.Windows.Controls.ComboBox]
        $Parent.Children[0].Name | Should -Be "ComboBox_$Id"
    }
}
