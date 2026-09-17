BeforeAll {
    $CollisionModule = New-Module -Name 'FindAstNodeCollision' -ScriptBlock {
        function Find-AstNode {
            throw 'The colliding Find-AstNode command was invoked.'
        }

        Export-ModuleMember -Function Find-AstNode
    }
    Import-Module $CollisionModule -Force

    $RulesPath = Join-Path $PSScriptRoot '../RHScriptAnalyzerRules.psd1'
    $ImportOutput = @(Import-Module $RulesPath -Force)
}

AfterAll {
    Remove-Module RHScriptAnalyzerRules, FindAstNodeCollision -Force -ErrorAction SilentlyContinue
}

Describe 'Rules module' {
    It 'Imports without output and exports only analyzer rules' {
        $ImportOutput.Count | Should -Be 0
        @(Get-Command -Module RHScriptAnalyzerRules).Name | Should -Be @(
            'Test-AvoidParameterAttributeBool'
            'Test-UseIsNotOperator'
        )
        Get-Command Find-WPFAstNode -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'Does not use a colliding Find-AstNode command' {
        { Test-UseIsNotOperator -ScriptBlockAst { -not ($Value -is [string]) }.Ast } |
            Should -Not -Throw
    }
}
