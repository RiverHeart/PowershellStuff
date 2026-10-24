BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Unregister-Nitpick' {
    BeforeEach {
        InModuleScope Nitpick {
            $Registry = Get-NitpickRegistry
            $Registry.Nitpicks.Clear()
            $Registry.Nitpicks['Style-Alpha'] = [pscustomobject] @{
                Name = 'Style-Alpha'
                Category = 'Style'
            }
            $Registry.Nitpicks['Style-Beta'] = [pscustomobject] @{
                Name = 'Style-Beta'
                Category = 'Style'
            }
            $Registry.Nitpicks['Quality-Alpha'] = [pscustomobject] @{
                Name = 'Quality-Alpha'
                Category = 'Quality'
            }
        }
    }

    It 'removes a rule by exact name' {
        Unregister-Nitpick -Name Style-Alpha

        InModuleScope Nitpick {
            $Registry = Get-NitpickRegistry
            $Registry.Nitpicks.ContainsKey('Style-Alpha') | Should -BeFalse
            $Registry.Nitpicks.ContainsKey('Style-Beta') | Should -BeTrue
        }
    }

    It 'supports wildcard names' {
        Unregister-Nitpick -Name '*Alpha'

        InModuleScope Nitpick {
            $Registry = Get-NitpickRegistry
            $Registry.Nitpicks.ContainsKey('Style-Alpha') | Should -BeFalse
            $Registry.Nitpicks.ContainsKey('Quality-Alpha') | Should -BeFalse
            $Registry.Nitpicks.ContainsKey('Style-Beta') | Should -BeTrue
        }
    }

    It 'limits removal to the requested type' {
        Unregister-Nitpick -Name '*' -Category Style

        InModuleScope Nitpick {
            $Registry = Get-NitpickRegistry
            $Registry.Nitpicks.ContainsKey('Style-Alpha') | Should -BeFalse
            $Registry.Nitpicks.ContainsKey('Style-Beta') | Should -BeFalse
            $Registry.Nitpicks.ContainsKey('Quality-Alpha') | Should -BeTrue
        }
    }

    It 'removes all rules when All is specified' {
        Unregister-Nitpick -All

        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Count | Should -Be 0
        }
    }
}
