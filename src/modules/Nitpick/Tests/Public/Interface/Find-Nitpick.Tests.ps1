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

            function Measure-ValidNitpick {
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
                'Measure-ValidNitpick'
                'Test-InvalidNitpick'
                'Get-UnrelatedCommand'
            )
        }
        Import-Module -ModuleInfo $RuleModule -Force
    }

    AfterEach {
        Remove-Module -Name NitpickDiscoveryRules -Force -ErrorAction SilentlyContinue
    }

    It 'returns valid Test and Measure commands from the requested module' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules)

        $Rules.Count | Should -Be 2
        $Rules.Name | Should -Contain 'Test-ValidNitpick'
        $Rules.Name | Should -Contain 'Measure-ValidNitpick'
    }

    It 'does not return commands from modules not requested' {
        $Rules = @(Find-Nitpick -Module Nitpick)

        $Rules.Name | Should -Not -Contain 'Test-ValidNitpick'
        $Rules.Name | Should -Not -Contain 'Measure-ValidNitpick'
    }
}
