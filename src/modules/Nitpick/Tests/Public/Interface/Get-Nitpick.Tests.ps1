BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Get-Nitpick' {
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

    It 'returns all registered rules by default' {
        $Rules = @(Get-Nitpick)

        $Rules.Count | Should -Be 3
        $Rules.Name | Should -Contain 'Style-Alpha'
        $Rules.Name | Should -Contain 'Quality-Alpha'
    }

    It 'filters rules by category' {
        $Rules = @(Get-Nitpick -Category Quality)

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'Quality-Alpha'
    }

    It 'filters rules by wildcard name' {
        $Rules = @(Get-Nitpick -Name '*Alpha')

        $Rules.Count | Should -Be 2
        $Rules.Name | Should -Contain 'Style-Alpha'
        $Rules.Name | Should -Contain 'Quality-Alpha'
    }

    It 'matches any of multiple name patterns' {
        $Rules = @(Get-Nitpick -Name 'Style-*', 'Quality-*')

        $Rules.Count | Should -Be 3
    }

    It 'combines name and Category filters' {
        $Rules = @(Get-Nitpick -Name '*Alpha' -Category Style)

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'Style-Alpha'
    }
}
