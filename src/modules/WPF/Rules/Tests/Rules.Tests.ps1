BeforeAll {
    $CollisionModule = New-Module -Name 'FindAstNodeCollision' -ScriptBlock {
        function Find-AstNode {
            throw 'The colliding Find-AstNode command was invoked.'
        }

        Export-ModuleMember -Function Find-AstNode
    }
    Import-Module $CollisionModule -Force

    $RulesPath = Join-Path $PSScriptRoot '../Rules.psd1'
    $ImportOutput = @(Import-Module $RulesPath -Force)
}

AfterAll {
    Remove-Module Rules, FindAstNodeCollision -Force -ErrorAction SilentlyContinue
}

Describe 'Rules module' {
    It 'Imports without output and exports only analyzer rules' {
        $ImportOutput.Count | Should -Be 0
        @(Get-Command -Module Rules).Name | Should -Be @(
            'Test-AvoidMandatoryAttributeBool'
            'Test-UseIsNotOperator'
        )
        Get-Command Find-WPFAstNode -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'Does not use a colliding Find-AstNode command' {
        { Test-UseIsNotOperator -ScriptBlockAst { -not ($Value -is [string]) }.Ast } |
            Should -Not -Throw
    }
}

Describe 'Test-AvoidMandatoryAttributeBool' {
    It 'Reports explicit Mandatory values' -ForEach @(
        @{ Value = '$true' }
        @{ Value = '$false' }
    ) {
        $ScriptBlockAst = [scriptblock]::Create("
            param(
                [Parameter(Mandatory=$Value)]
                [string] `$Name
            )
        ").Ast

        $Result = @(Test-AvoidMandatoryAttributeBool -ScriptBlockAst $ScriptBlockAst)

        $Result.Count | Should -Be 1
        $Result[0].RuleName | Should -Be 'Test-AvoidMandatoryAttributeBool'
        $Result[0].Severity | Should -Be 'Warning'
        $Result[0].RuleSuppressionId | Should -Be 'PSAvoidMandatoryAttributeBool'
        $Result[0].Message | Should -BeLike '*Parameter(Mandatory)*'
    }

    It 'Does not report an omitted Mandatory expression' {
        $Result = @(Test-AvoidMandatoryAttributeBool -ScriptBlockAst {
            param(
                [Parameter(Mandatory)]
                [string] $Name
            )
        }.Ast)

        $Result.Count | Should -Be 0
    }

    It 'Does not report unrelated Parameter attribute arguments' {
        $Result = @(Test-AvoidMandatoryAttributeBool -ScriptBlockAst {
            param(
                [Parameter(ValueFromPipeline=$true)]
                [string] $Name
            )
        }.Ast)

        $Result.Count | Should -Be 0
    }
}

Describe 'Test-UseIsNotOperator' {
    It 'Reports a negated is expression' {
        $Result = @(Test-UseIsNotOperator -ScriptBlockAst {
            -not ($Value -is [string])
        }.Ast)

        $Result.Count | Should -Be 1
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

    It 'Accepts a file path as input' {
        $TestFile = Join-Path $TestDrive 'ImproperIsUsage.ps1'
        Set-Content -LiteralPath $TestFile -Value '-not ($Value -is [string])'

        $Result = @(Test-UseIsNotOperator -FilePath $TestFile)

        $Result.Count | Should -Be 1
    }
}
