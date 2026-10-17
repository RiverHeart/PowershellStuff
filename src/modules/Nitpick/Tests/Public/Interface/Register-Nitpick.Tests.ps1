BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force

    function Test-DriftedNitpickRule {
        [CmdletBinding()]
        param (
            $ScriptBlockAst,
            [switch] $Details
        )

        if ($Details) {
            return @{ Name = 'DifferentRuleName' }
        }
    }
}

AfterAll {
    Remove-Item -Path Function:\Test-DriftedNitpickRule -ErrorAction SilentlyContinue
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Register-Nitpick' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'registers a rule in the Nitpick registry' {
        Register-Nitpick -Callable {
            param ($ScriptBlockAst)
        } -Category Style -Name TestRule -Source Tests

        InModuleScope Nitpick {
            $Registry = Get-NitpickRegistry
            $Registry.Nitpicks.ContainsKey('Local/TestRule') | Should -BeTrue
            $Registry.Nitpicks['Local/TestRule'].Category | Should -Be 'Style'
        }
    }

    It 'returns the registered rule when PassThru is specified' {
        $Rule = Register-Nitpick -Callable {
            param ($ScriptBlockAst)
        } -Category Quality -Name TestRule -Source Tests -PassThru

        $Rule.GetType().Name | Should -Be 'NitpickRule'
        $Rule.Name | Should -Be 'TestRule'
        $Rule.Category | Should -Be 'Quality'
    }

    It 'is idempotent when the same rule is already registered' {
        $Parameters = @{
            Callable = { param ($ScriptBlockAst) }
            Category = 'Style'
            Name = 'TestRule'
            Source = 'Tests'
        }
        Register-Nitpick @Parameters

        $Rule = Register-Nitpick @Parameters -PassThru

        $Rule.Name | Should -Be 'TestRule'
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Count | Should -Be 1
        }
    }

    It 'rejects a different rule with the same name without Force' {
        Register-Nitpick -Callable {
            param ($ScriptBlockAst)
            'old'
        } -Category Style -Name TestRule -Source Tests

        {
            Register-Nitpick -Callable {
                param ($ScriptBlockAst)
                'new'
            } -Category Style -Name TestRule -Source Tests -ErrorAction Stop
        } | Should -Throw '*already registered*'
    }

    It 'recognizes lookup and discovery wrappers for the same exported function' {
        $Original = Register-Nitpick -Callable (Get-Command Test-UseIsNotOperator -Module Nitpick) -PassThru
        $Repeated = Find-Nitpick -IncludeRule 'Nitpick/UseIsNotOperator' |
            Register-Nitpick -PassThru -ErrorAction Stop
        [object]::ReferenceEquals($Original, $Repeated) | Should -BeTrue
    }

    It 'replaces a duplicate rule when Force is specified' {
        Register-Nitpick -Callable {
            param ($ScriptBlockAst)
            'old'
        } -Category Style -Name TestRule -Source Tests

        Register-Nitpick -Callable {
            param ($ScriptBlockAst)
            'new'
        } -Category Performance -Name TestRule -Source Tests -Force

        InModuleScope Nitpick {
            $Rule = (Get-NitpickRegistry).Nitpicks['Local/TestRule']
            $Rule.Category | Should -Be 'Performance'
            & $Rule.Callable $null | Should -Be 'new'
        }
    }

    It 'rejects a callable with an invalid signature' {
        {
            Register-Nitpick `
                -Callable { param ($FilePath) } `
                -Category Style `
                -Name InvalidRule `
                -Source Tests `
                -ErrorAction Stop
        } | Should -Throw '*ScriptBlockAst*'
    }

    It 'rejects a command-backed rule whose name differs from its callable noun' {
        {
            Register-Nitpick `
                -Callable (Get-Command Test-DriftedNitpickRule) `
                -Source Tests `
                -ErrorAction Stop
        } | Should -Throw "*must match callable name 'DriftedNitpickRule'*"
    }

    It 'registers only included discovered rule IDs' {
        $Rules = @(Register-Nitpick `
            -Module Nitpick `
            -IncludeRule Nitpick/UseIsNotOperator `
            -PassThru)

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'UseIsNotOperator'
    }

    It 'does not register excluded discovered rule IDs' {
        $Rules = @(Register-Nitpick `
            -Module Nitpick `
            -ExcludeRule Nitpick/UseIsNotOperator `
            -PassThru)

        $Rules.Name | Should -Not -Contain 'UseIsNotOperator'
        $Rules.Name | Should -Contain 'AvoidParameterAttributeBool'
    }

    It 'registers an existing NitpickRule without reconstructing it' {
        $Rule = New-Nitpick -Callable {
            param ($ScriptBlockAst)
        } -Category Style -Name ExistingRule -Source Tests

        $RegisteredRule = $Rule | Register-Nitpick -PassThru

        [object]::ReferenceEquals($Rule, $RegisteredRule) | Should -BeTrue
    }
}
