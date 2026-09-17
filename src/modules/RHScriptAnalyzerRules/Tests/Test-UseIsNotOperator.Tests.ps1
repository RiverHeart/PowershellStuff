BeforeAll {
    $RulesPath = Join-Path $PSScriptRoot '../RHScriptAnalyzerRules.psd1'
    Import-Module $RulesPath -Force
}

Describe 'Test-UseIsNotOperator' {
    It 'Reports a negated is expression' {
        $Result = @(Test-UseIsNotOperator -ScriptBlockAst {
            if (-not ($Value -is [string])) {}

            if (-not ($Value -is [string])) {}
        }.Ast)

        $Result.Count | Should -Be 2
        $Result[0].RuleName | Should -Be 'Test-UseIsNotOperator'
        $Result[0].Severity | Should -Be 'Warning'
        $Result[0].RuleSuppressionId | Should -Be 'PSUseIsNotOperator'
        $Result[0].Message | Should -BeLike '*-isnot*'
    }

    It 'Does not report an isnot expression' {
        $Result = @(Test-UseIsNotOperator -ScriptBlockAst {
            $Value -isnot [string]
        }.Ast)

        $Result.Count | Should -Be 0
    }

    It 'Does not report another negated binary expression' {
        $Result = @(Test-UseIsNotOperator -ScriptBlockAst {
            -not ($Value -eq 'example')
        }.Ast)

        $Result.Count | Should -Be 0
    }
}
