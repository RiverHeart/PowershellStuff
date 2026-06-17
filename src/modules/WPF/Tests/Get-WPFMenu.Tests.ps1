Describe 'Get-WPFMenu' -Tag 'Get-WPFMenu' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
    }

    It 'Should resolve the stable menu reference from active context' {
        $Id = [guid]::NewGuid().ToString('N')

        $Window = Window "Window_$Id" {
            Menu "Menu_$Id" { }
        }

        $ExpectedContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $ExpectedMenu = Reference '__WPFMenu' -ContextId $ExpectedContextId

        $ResolvedMenu = Get-WPFMenu

        $ResolvedMenu | Should -BeExactly -ExpectedValue $ExpectedMenu
    }

    It 'Should resolve a menu by explicit Window input' {
        $Id = [guid]::NewGuid().ToString('N')

        $Window = Window "Window_$Id" {
            Menu "Menu_$Id" { }
        }

        $ExpectedContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $ExpectedMenu = Reference '__WPFMenu' -ContextId $ExpectedContextId

        $ResolvedMenu = Get-WPFMenu -Window $Window

        $ResolvedMenu | Should -BeExactly -ExpectedValue $ExpectedMenu
    }

    It 'Should return null when no menu exists in the resolved context' {
        $Id = [guid]::NewGuid().ToString('N')

        $null = Window "Window_$Id" {
            Button "Button_$Id" { }
        }

        $ResolvedMenu = Get-WPFMenu

        $ResolvedMenu | Should -Be $null
    }
}
