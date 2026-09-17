BeforeAll {
    $RulesPath = Join-Path $PSScriptRoot '../RHScriptAnalyzerRules.psd1'
    Import-Module $RulesPath -Force
}

Describe 'Test-AvoidParameterAttributeBool' {
    BeforeDiscovery {
        $SupportedAttributes = @(
            'Mandatory'
            'ValueFromPipeline'
            'ValueFromPipelineByPropertyName'
            'ValueFromRemainingArguments'
            'DontShow'
        )
        $TestMatrix = foreach ($Attribute in $SupportedAttributes) {
            @{ Attribute = $Attribute; Value = '$true' }
            @{ Attribute = $Attribute; Value = '$false' }
        }
    }

    It 'Reports explicit Mandatory values' -ForEach $TestMatrix {
        $ScriptBlockAst = [scriptblock]::Create("
            param(
                [Parameter($Attribute=$Value)]
                [string] `$Name
            )
        ").Ast

        $Result = @(Test-AvoidParameterAttributeBool -ScriptBlockAst $ScriptBlockAst)

        $Result.Count | Should -Be 1
        $Result[0].RuleName | Should -Be 'Test-AvoidParameterAttributeBool'
        $Result[0].Severity | Should -Be 'Warning'
        $Result[0].RuleSuppressionId | Should -Be 'PSAvoidParameterAttributeBool'
        $Result[0].Message | Should -Be 'Avoid assigning Boolean values to Parameter attribute arguments'
    }

    It 'Does not report an omitted attribute expression' -ForEach $SupportedAttributes {
        $ScriptBlockAst = [scriptblock]::create("
            param(
                [Parameter($Attribute)]
                [string] `$Name
            )
        ").Ast

        $Result = @(Test-AvoidParameterAttributeBool -ScriptBlockAst $ScriptBlockAst)

        $Result.Count | Should -Be 0
    }

    It 'Does not report unrelated Parameter attribute arguments' {
        $Result = @(Test-AvoidParameterAttributeBool -ScriptBlockAst {
            param(
                [Parameter(HelpMessage='This is a help message')]
                [string] $Name
            )
        }.Ast)

        $Result.Count | Should -Be 0
    }
}
