Describe 'Border DSL' -Tag 'Border' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    BeforeAll {
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should create and auto-attach a named border' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()
        $psVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Border "Border_$Id" {
                $this.Padding = 4
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be -ExpectedValue 0
        $Parent.Content | Should -BeOfType [System.Windows.Controls.Border]
        $Parent.Content.Name | Should -Be -ExpectedValue "Border_$Id"
        $Parent.Content.Padding.Left | Should -Be -ExpectedValue 4
    }

    It 'Should support nameless border syntax' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.Button]::new()
        $psVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Border {
                Label "BorderChild_$Id" {}
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be -ExpectedValue 0
        $Parent.Content | Should -BeOfType [System.Windows.Controls.Border]
        $Parent.Content.Child | Should -BeOfType [System.Windows.Controls.Label]
        $Parent.Content.Child.Name | Should -Be -ExpectedValue "BorderChild_$Id"
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $Result = {
            -Border "Border_$Id" {
                $this.Padding = 4
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }

    It 'Should return border object when grid child-collection context is active' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.Grid]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Border "Border_$Id" {
                $this.Padding = 2
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be 1
        @($Result)[0] | Should -BeOfType [System.Windows.Controls.Border]
        @($Result)[0].Name | Should -Be "Border_$Id"
        $Parent.Children | Should -HaveCount 1
    }
}
