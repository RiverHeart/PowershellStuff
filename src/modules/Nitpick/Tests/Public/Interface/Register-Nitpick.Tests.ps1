BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
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
        } -Type Style -Name TestRule -Source Tests

        InModuleScope Nitpick {
            $Registry = Get-NitpickRegistry
            $Registry.Nitpicks.ContainsKey('TestRule') | Should -BeTrue
            $Registry.Nitpicks.TestRule.Type | Should -Be 'Style'
        }
    }

    It 'returns the registered rule when PassThru is specified' {
        $Rule = Register-Nitpick -Callable {
            param ($ScriptBlockAst)
        } -Type Quality -Name TestRule -Source Tests -PassThru

        $Rule.PSObject.TypeNames | Should -Contain 'Nitpick.Rule'
        $Rule.Name | Should -Be 'TestRule'
        $Rule.Type | Should -Be 'Quality'
    }

    It 'rejects a duplicate rule without Force' {
        $Parameters = @{
            Callable = { param ($ScriptBlockAst) }
            Type = 'Style'
            Name = 'TestRule'
            Source = 'Tests'
        }
        Register-Nitpick @Parameters

        { Register-Nitpick @Parameters -ErrorAction Stop } |
            Should -Throw '*already registered*'
    }

    It 'replaces a duplicate rule when Force is specified' {
        Register-Nitpick -Callable {
            param ($ScriptBlockAst)
            'old'
        } -Type Style -Name TestRule -Source Tests

        Register-Nitpick -Callable {
            param ($ScriptBlockAst)
            'new'
        } -Type Performance -Name TestRule -Source Tests -Force

        InModuleScope Nitpick {
            $Rule = (Get-NitpickRegistry).Nitpicks.TestRule
            $Rule.Type | Should -Be 'Performance'
            & $Rule.Callable $null | Should -Be 'new'
        }
    }

    It 'rejects a callable with an invalid signature' {
        {
            Register-Nitpick `
                -Callable { param ($FilePath) } `
                -Type Style `
                -Name InvalidRule `
                -Source Tests `
                -ErrorAction Stop
        } | Should -Throw '*ScriptBlockAst*'
    }
}
