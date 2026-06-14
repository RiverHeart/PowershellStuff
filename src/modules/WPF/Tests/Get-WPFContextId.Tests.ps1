Describe 'Get-WPFContextId' -Tag 'Get-WPFContextId' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
    }

    It 'Should resolve the current context id from object context' {
        $Id = [guid]::NewGuid().ToString('N')

        $Window = Window "Window_$Id" {
            Button "Button_$Id" {}
        }

        $ExpectedContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Button = Reference "Button_$Id" -ContextId $ExpectedContextId
        $Vars = New-WPFVariableList -InputObject $Button
        $ResolvedContextId = { Get-WPFContextId }.InvokeWithContext($null, $Vars)

        $ResolvedContextId | Should -Be $ExpectedContextId
    }

    It 'Should resolve the active context id when called without object context' {
        $Id = [guid]::NewGuid().ToString('N')

        $null = Window "WindowA_$Id" {}
        $SecondWindow = Window "WindowB_$Id" {}

        $ExpectedContextId = [string] $SecondWindow.PSObject.Properties['_WPFContextId'].Value
        $ResolvedContextId = Get-WPFContextId

        $ResolvedContextId | Should -Be $ExpectedContextId
    }

    It 'Should resolve a context id by explicit input object' {
        $Id = [guid]::NewGuid().ToString('N')

        $Window = Window "Window_$Id" {
            Button "Button_$Id" {}
        }

        $ExpectedContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Button = Reference "Button_$Id" -ContextId $ExpectedContextId
        $ResolvedContextId = Get-WPFContextId -InputObject $Button

        $ResolvedContextId | Should -Be $ExpectedContextId
    }

    It 'Should resolve App root context id from child object context' {
        $Id = [guid]::NewGuid().ToString('N')

        $AppWindow = App "App_$Id" {
            Button "Button_$Id" {}
        }

        $ExpectedContextId = [string] $AppWindow.PSObject.Properties['_WPFContextId'].Value
        $Button = Reference "Button_$Id" -ContextId $ExpectedContextId
        $Vars = New-WPFVariableList -InputObject $Button
        $ResolvedContextId = { Get-WPFContextId }.InvokeWithContext($null, $Vars)

        $ResolvedContextId | Should -Be $ExpectedContextId
    }

    It 'Should throw when there is no resolvable context' {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }

        { Get-WPFContextId -ErrorAction Stop } | Should -Throw '*No current context id is available*'
    }
}
