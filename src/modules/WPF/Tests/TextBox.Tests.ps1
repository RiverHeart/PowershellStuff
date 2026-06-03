Describe 'TextBox' -Tag 'TextBox' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        {
            -TextBox "TextBox_$Id" {
                $this.Text = "Input"
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }

    It 'Should return textbox object when no parent context exists' {
        $Id = [guid]::NewGuid().ToString('N')

        $TextBox = TextBox "TextBox_$Id" {
            $this.Text = 'Input'
        }

        $TextBox | Should -Not -BeNullOrEmpty
        $TextBox | Should -BeOfType [System.Windows.Controls.TextBox]
        $TextBox.Name | Should -Be "TextBox_$Id"
        $TextBox.Text | Should -Be 'Input'
    }

    It 'Should auto-attach to parent context and return no output' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.StackPanel]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            TextBox "TextBox_$Id" {
                $this.Text = 'Input'
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be 0
        $Parent.Children | Should -HaveCount 1
        $Parent.Children[0] | Should -BeOfType [System.Windows.Controls.TextBox]
        $Parent.Children[0].Name | Should -Be "TextBox_$Id"
        $Parent.Children[0].Text | Should -Be 'Input'
    }

    It 'Should return textbox object when grid child-collection context is active' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.Grid]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            TextBox "TextBox_$Id" {
                $this.Text = 'Input'
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be 1
        @($Result)[0] | Should -BeOfType [System.Windows.Controls.TextBox]
        @($Result)[0].Name | Should -Be "TextBox_$Id"
        $Parent.Children | Should -HaveCount 1
    }
}
