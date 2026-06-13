Describe 'Get-WPFWindow' -Tag 'Get-WPFWindow' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
    }

    It 'Should resolve the current window from object context' {
        $Id = [guid]::NewGuid().ToString('N')

        $Window = Window "Window_$Id" {
            Button "Button_$Id" {}
        }

        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Button = Reference "Button_$Id" -ContextId $ContextId
        $Vars = New-WPFVariableList -InputObject $Button
        $ResolvedWindow = { Get-WPFWindow }.InvokeWithContext($null, $Vars)

        $ResolvedWindow | Should -BeExactly -ExpectedValue $Window
    }

    It 'Should resolve the active context window when called without object context' {
        $Id = [guid]::NewGuid().ToString('N')

        $FirstWindow = Window "WindowA_$Id" {}
        $SecondWindow = Window "WindowB_$Id" {}

        $ResolvedWindow = Get-WPFWindow

        $ResolvedWindow | Should -BeExactly -ExpectedValue $SecondWindow
        $ResolvedWindow | Should -Not -Be -ExpectedValue $FirstWindow
    }

    It 'Should resolve the only registered window when no active context is set' {
        $Id = [guid]::NewGuid().ToString('N')

        $Window = Window "Window_$Id" {}
        InModuleScope WPF {
            (Get-WPFControlRegistry).ActiveContextId = $null
        }

        $ResolvedWindow = Get-WPFWindow

        $ResolvedWindow | Should -BeExactly -ExpectedValue $Window
    }

    It 'Should resolve a window by explicit ContextId' {
        $Id = [guid]::NewGuid().ToString('N')

        $FirstWindow = Window "WindowA_$Id" {}
        $null = Window "WindowB_$Id" {}

        $FirstContextId = [string] $FirstWindow.PSObject.Properties['_WPFContextId'].Value
        $ResolvedWindow = Get-WPFWindow -ContextId $FirstContextId

        $ResolvedWindow | Should -BeExactly -ExpectedValue $FirstWindow
    }

    It 'Should resolve App root window from child object context' {
        $Id = [guid]::NewGuid().ToString('N')

        $AppWindow = App "App_$Id" {
            Button "Button_$Id" {}
        }

        $ContextId = [string] $AppWindow.PSObject.Properties['_WPFContextId'].Value
        $Button = Reference "Button_$Id" -ContextId $ContextId
        $Vars = New-WPFVariableList -InputObject $Button
        $ResolvedWindow = { Get-WPFWindow }.InvokeWithContext($null, $Vars)

        $ResolvedWindow | Should -BeExactly -ExpectedValue $AppWindow
    }

    It 'Should return null when there is no discoverable window context' {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }

        Get-WPFWindow | Should -Be $null
    }

    It 'Should throw when explicit ContextId cannot be resolved' {
        { Get-WPFWindow -ContextId 'missing-context' -ErrorAction Stop } | Should -Throw '*No WPF control context exists*'
    }
}
