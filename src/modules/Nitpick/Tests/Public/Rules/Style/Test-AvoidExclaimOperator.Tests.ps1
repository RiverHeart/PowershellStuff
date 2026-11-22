using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../../../Nitpick.psd1') -Force -ErrorAction Stop
}

Describe 'Test-AvoidExclaimOperator' {
    It 'reports exclaim expressions and replaces the operator: <Label>' -ForEach @(
        @{ Label = 'ordinary spacing'; Source = '! $Value'; Expected = '-not $Value' }
        @{ Label = 'adjacent operand'; Source = '!$Value'; Expected = '-not $Value' }
        @{ Label = 'parenthesized operand'; Source = '!($Value)'; Expected = '-not ($Value)' }
        @{ Label = 'block comment trivia'; Source = '!<# keep #>$Value'; Expected = '-not <# keep #>$Value' }
        @{ Label = 'type test'; Source = '!($Value -is [string])'; Expected = '-not ($Value -is [string])' }
        @{
            Label = 'nested interpolation'
            Source = '"outer $("inner $(! $Value)")"'
            Expected = '"outer $("inner $(-not $Value)")"'
        }
    ) {
        $Document = New-AstDocument -InputObject $Source
        $Rule = New-Nitpick -Callable Test-AvoidExclaimOperator

        $Findings = @($Rule.Invoke($Document.Ast))

        $Document.ParseErrors | Should -BeNullOrEmpty
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/AvoidExclaimOperator'
        $Findings[0].Severity | Should -Be 'Information'
        $Findings[0].Message | Should -BeLike "*'!'*'-not'*"
        $Findings[0].Corrections | Should -HaveCount 1
        $Findings[0].Corrections[0].TextEdits | Should -HaveCount 1

        $Result = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding $Findings `
            -Rule $Rule

        $Result.CandidateText | Should -BeExactly $Expected
        $Result.CandidateFindings | Should -HaveCount 0
    }

    It 'corrects independent expressions' {
        $Document = New-AstDocument -InputObject '! $First; !$Second'
        $Rule = New-Nitpick -Callable Test-AvoidExclaimOperator
        $Findings = @($Rule.Invoke($Document.Ast))

        $Findings | Should -HaveCount 2
        $Result = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding $Findings `
            -Rule $Rule

        $Result.CandidateText | Should -BeExactly '-not $First; -not $Second'
        $Result.AcceptedCorrections | Should -HaveCount 2
    }

    It 'does not report keyword negation' {
        @(Test-AvoidExclaimOperator -ScriptBlockAst { -not $Value }.Ast) |
            Should -HaveCount 0
    }

    It 'respects nested scriptblock traversal' {
        $Source = '& { ! $Value }'
        $Document = New-AstDocument -InputObject $Source
        $NestedAst = $Document.Ast.Find({
            param($Node)
            $Node -is [ScriptBlockAst] -and $Node.Parent -is [ScriptBlockExpressionAst]
        }, $true)

        @(Test-AvoidExclaimOperator -ScriptBlockAst $Document.Ast) |
            Should -HaveCount 0
        @(Test-AvoidExclaimOperator `
            -ScriptBlockAst $Document.Ast `
            -Context @{ RuleBehavior = @{ SearchNestedScriptBlocks = $true } }) |
            Should -HaveCount 1
        @(Test-AvoidExclaimOperator -ScriptBlockAst $NestedAst) |
            Should -HaveCount 1
    }
}
