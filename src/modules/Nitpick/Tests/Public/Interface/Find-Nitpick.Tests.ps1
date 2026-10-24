using namespace System.Management.Automation

BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Find-Nitpick' {
    BeforeEach {
        $RuleModule = New-Module -Name NitpickDiscoveryRules -ScriptBlock {
            function Test-ValidNitpick {
                param ($ScriptBlockAst)
            }

            function Measure-OtherValidNitpick {
                param ($ScriptBlockAst)
            }

            function Test-InvalidNitpick {
                param ($FilePath)
            }

            function Get-UnrelatedCommand {
                param ($ScriptBlockAst)
            }

            Export-ModuleMember -Function @(
                'Test-ValidNitpick'
                'Measure-OtherValidNitpick'
                'Test-InvalidNitpick'
                'Get-UnrelatedCommand'
            )
        }
        Import-Module -ModuleInfo $RuleModule -Force
    }

    AfterEach {
        Remove-Module -Name NitpickDiscoveryRules -Force -ErrorAction SilentlyContinue
    }

    It 'returns only the built-in package by default' {
        $Rules = @(Find-Nitpick)

        $Rules | Should -Not -BeNullOrEmpty
        @($Rules | Where-Object Namespace -ne Nitpick) | Should -HaveCount 0
        $Rules.Id | Should -Contain 'Nitpick/UseIsNotOperator'
    }

    It 'acquires nothing when IncludeDefaults is explicitly suppressed with no Module' {
        $Rules = @(Find-Nitpick -IncludeDefaults:$false)

        $Rules | Should -HaveCount 0
    }

    It 'does not discover an unrelated loaded module by default' {
        $Rules = @(Find-Nitpick)

        $Rules.Name | Should -Not -Contain 'ValidNitpick'
    }

    It 'acquires an explicitly requested module as a standalone package' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules)

        $Rules.Count | Should -Be 2
        $Rules.Id | Should -Contain 'NitpickDiscoveryRules/ValidNitpick'
        $Rules.Id | Should -Contain 'NitpickDiscoveryRules/OtherValidNitpick'
        $Rules.Namespace | Should -Contain 'NitpickDiscoveryRules'
    }

    It 'does not include an exported command missing the required parameter' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules)

        $Rules.Name | Should -Not -Contain 'InvalidNitpick'
    }

    It 'does not include an unrelated exported command' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules)

        $Rules.Name | Should -Not -Contain 'UnrelatedCommand'
    }

    It 'filters rules by wildcard qualified ID' {
        $Rules = @(Find-Nitpick `
            -Module NitpickDiscoveryRules `
            -IncludeRule 'NitpickDiscoveryRules/*Valid*'
        )

        $Rules.Count | Should -Be 2
    }

    It 'excludes rules by qualified ID' {
        $Rules = @(Find-Nitpick `
            -Module NitpickDiscoveryRules `
            -ExcludeRule 'NitpickDiscoveryRules/*'
        )

        $Rules.Count | Should -Be 0
    }

    It 'allows unmatched include selectors without raising an error' {
        $Errors = @()
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules `
            -IncludeRule 'NitpickDiscoveryRules/MissingRule' -ErrorAction Stop -ErrorVariable Errors)

        $Rules | Should -HaveCount 0
        $Errors | Should -HaveCount 0
    }

    It 'replaces the built-in default with a single explicit module entry' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules)

        @($Rules | Where-Object Namespace -eq Nitpick) | Should -HaveCount 0
        @($Rules | Where-Object Namespace -eq NitpickDiscoveryRules) | Should -HaveCount 2
    }

    It 'accepts multiple module entries additively' {
        $Rules = @(Find-Nitpick -Module Nitpick, NitpickDiscoveryRules)

        @($Rules | Where-Object Namespace -eq Nitpick) | Should -Not -BeNullOrEmpty
        @($Rules | Where-Object Namespace -eq NitpickDiscoveryRules) | Should -HaveCount 2
    }

    It 'acquires the built-in package alongside an explicit module when IncludeDefaults is specified' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules -IncludeDefaults)

        @($Rules | Where-Object Namespace -eq Nitpick) | Should -Not -BeNullOrEmpty
        @($Rules | Where-Object Namespace -eq NitpickDiscoveryRules) | Should -HaveCount 2
    }

    It 'writes a non-terminating error and continues past an unresolvable module' {
        $Errors = @()
        $Rules = @(
            Find-Nitpick `
            -Module 'NitpickDiscoveryRules', 'MissingModule' `
            -ErrorAction SilentlyContinue `
            -ErrorVariable Errors
        )

        $Rules.Count | Should -Be 2
        $Errors | Should -Not -BeNullOrEmpty
    }
}
