Describe 'Menu' -Tag 'Menu' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $Result = {
            -Menu "Menu_$Id" {
                MenuItem "File_$Id" {}
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }

    It 'Should return menu object when no parent context exists' {
        $Id = [guid]::NewGuid().ToString('N')

        $MenuObject = Menu "Menu_$Id" {
            MenuItem "File_$Id" {}
        }

        $MenuObject | Should -Not -BeNullOrEmpty
        $MenuObject | Should -BeOfType [System.Windows.Controls.Menu]
        $MenuObject.Name | Should -Be "Menu_$Id"
    }

    It 'Should auto-attach to parent context and return no output' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.DockPanel]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Menu "Menu_$Id" {
                MenuItem "File_$Id" {}
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be 0
        $Parent.Children | Should -HaveCount 1
        $Parent.Children[0] | Should -BeOfType [System.Windows.Controls.Menu]
        $Parent.Children[0].Name | Should -Be "Menu_$Id"
    }

    It 'Should return menu object when grid child-collection context is active' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.Grid]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Menu "Menu_$Id" {
                MenuItem "File_$Id" {}
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be 1
        @($Result)[0] | Should -BeOfType [System.Windows.Controls.Menu]
        @($Result)[0].Name | Should -Be "Menu_$Id"
        $Parent.Children | Should -HaveCount 1
    }
}
