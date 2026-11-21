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

    It 'removes a rule by exact ID' {
        Unregister-Nitpick -Id Style-Alpha

        InModuleScope Nitpick {
            $Registry = Get-NitpickRegistry
            $Registry.Nitpicks.ContainsKey('Style-Alpha') | Should -BeFalse
            $Registry.Nitpicks.ContainsKey('Style-Beta') | Should -BeTrue
        }
    }

    It 'removes a rule by case-insensitive exact ID' {
        Unregister-Nitpick -Id STYLE-ALPHA

        InModuleScope Nitpick {
            $Registry = Get-NitpickRegistry
            $Registry.Nitpicks.ContainsKey('Style-Alpha') | Should -BeFalse
            $Registry.Nitpicks.ContainsKey('Style-Beta') | Should -BeTrue
        }
    }

    It 'supports wildcard IDs' {
        Unregister-Nitpick -Id '*Alpha'

        InModuleScope Nitpick {
            $Registry = Get-NitpickRegistry
            $Registry.Nitpicks.ContainsKey('Style-Alpha') | Should -BeFalse
            $Registry.Nitpicks.ContainsKey('Quality-Alpha') | Should -BeFalse
            $Registry.Nitpicks.ContainsKey('Style-Beta') | Should -BeTrue
        }
    }

    It 'limits removal to the requested type' {
        Unregister-Nitpick -Id '*' -Category Style

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
