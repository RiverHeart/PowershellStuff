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

    It 'returns a rule by exact name' {
        $Rules = @(Get-Nitpick -Name 'Style-Alpha')

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'Style-Alpha'
    }

    It 'returns no rule when an exact name is not registered' {
        $Rules = @(Get-Nitpick -Name 'Missing-Rule')

        $Rules.Count | Should -Be 0
    }

    It 'combines name and Category filters' {
        $Rules = @(Get-Nitpick -Name 'Style-Alpha' -Category Style)

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'Style-Alpha'
    }

    It 'filters rules by wildcard include patterns' {
        $Rules = @(Get-Nitpick -IncludeRule '*-Alpha')

        $Rules.Count | Should -Be 2
        $Rules.Name | Should -Contain 'Style-Alpha'
        $Rules.Name | Should -Contain 'Quality-Alpha'
    }

    It 'matches any of multiple include patterns' {
        $Rules = @(Get-Nitpick -IncludeRule 'Style-Beta', 'Quality-*')

        $Rules.Count | Should -Be 2
        $Rules.Name | Should -Contain 'Style-Beta'
        $Rules.Name | Should -Contain 'Quality-Alpha'
    }

    It 'filters rules by wildcard exclude patterns' {
        $Rules = @(Get-Nitpick -ExcludeRule 'Style-*')

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'Quality-Alpha'
    }

    It 'applies exclusions after inclusions' {
        $Rules = @(Get-Nitpick -IncludeRule '*-Alpha' -ExcludeRule 'Quality-*')

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'Style-Alpha'
    }
}
