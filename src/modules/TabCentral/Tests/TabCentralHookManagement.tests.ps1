BeforeAll {
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

Describe 'Get-TabCentralHook' {
    BeforeEach {
        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters.Clear()
            $Registry.ResultModifiers.Clear()
            $Registry.TabCompleters['Complete-Alpha'] = [pscustomobject] @{
                Name = 'Complete-Alpha'
                Type = 'Completer'
            }
            $Registry.TabCompleters['Complete-Beta'] = [pscustomobject] @{
                Name = 'Complete-Beta'
                Type = 'Completer'
            }
            $Registry.ResultModifiers['Modify-Alpha'] = [pscustomobject] @{
                Name = 'Modify-Alpha'
                Type = 'Modifier'
            }
        }
    }

    It 'returns hooks from both hook types by default' {
        $Hooks = @(Get-TabCentralHook)

        $Hooks.Count | Should -Be 3
        $Hooks.Name | Should -Contain 'Complete-Alpha'
        $Hooks.Name | Should -Contain 'Modify-Alpha'
    }

    It 'filters hooks by type' {
        $Hooks = @(Get-TabCentralHook -Type Modifier)

        $Hooks.Count | Should -Be 1
        $Hooks[0].Name | Should -Be 'Modify-Alpha'
    }

    It 'filters hooks by wildcard name' {
        $Hooks = @(Get-TabCentralHook -Name '*Alpha')

        $Hooks.Count | Should -Be 2
        $Hooks.Name | Should -Contain 'Complete-Alpha'
        $Hooks.Name | Should -Contain 'Modify-Alpha'
    }
}

Describe 'Unregister-TabCentralHook' {
    BeforeEach {
        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters.Clear()
            $Registry.ResultModifiers.Clear()
            $Registry.TabCompleters['Complete-Alpha'] = 'completer'
            $Registry.TabCompleters['Complete-Beta'] = 'completer'
            $Registry.ResultModifiers['Complete-Alpha'] = 'modifier'
            $Registry.ResultModifiers['Modify-Beta'] = 'modifier'
        }
    }

    It 'removes an exact name from both hook types when type is omitted' {
        Unregister-TabCentralHook -Name Complete-Alpha

        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters.ContainsKey('Complete-Alpha') | Should -BeFalse
            $Registry.ResultModifiers.ContainsKey('Complete-Alpha') | Should -BeFalse
            $Registry.TabCompleters.ContainsKey('Complete-Beta') | Should -BeTrue
        }
    }

    It 'limits removal to the requested hook type' {
        Unregister-TabCentralHook -Name Complete-Alpha -Type Completer

        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters.ContainsKey('Complete-Alpha') | Should -BeFalse
            $Registry.ResultModifiers.ContainsKey('Complete-Alpha') | Should -BeTrue
        }
    }

    It 'supports wildcard names' {
        Unregister-TabCentralHook -Name '*Beta'

        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters.ContainsKey('Complete-Beta') | Should -BeFalse
            $Registry.ResultModifiers.ContainsKey('Modify-Beta') | Should -BeFalse
        }
    }

    It 'clears both hook types when All is specified' {
        Unregister-TabCentralHook -All

        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters.Count | Should -Be 0
            $Registry.ResultModifiers.Count | Should -Be 0
        }
    }
}
