BeforeAll {
    $RulesPath = Join-Path $PSScriptRoot '../../../Nitpick.psm1'
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
        $FalseArgumentCases = @(
            @{
                Position = 'first'
                Source = 'param([Parameter(Mandatory=$false,Position=0)] [string] $Name)'
                Expected = 'param([Parameter(Position=0)] [string] $Name)'
            }
            @{
                Position = 'middle'
                Source = "param([Parameter(Position=0,Mandatory=`$false,HelpMessage='Name')] [string] `$Name)"
                Expected = "param([Parameter(Position=0,HelpMessage='Name')] [string] `$Name)"
            }
            @{
                Position = 'last'
                Source = 'param([Parameter(Position=0,Mandatory=$false)] [string] $Name)'
                Expected = 'param([Parameter(Position=0)] [string] $Name)'
            }
            @{
                Position = 'only'
                Source = 'param([Parameter(Mandatory=$false)] [string] $Name)'
                Expected = 'param([Parameter()] [string] $Name)'
            }
            @{
                Position = 'multiline'
                Source = "param([Parameter(Position=0,`n    Mandatory=`$false,`n    HelpMessage='Name')] [string] `$Name)"
                Expected = "param([Parameter(Position=0,`n    `n    HelpMessage='Name')] [string] `$Name)"
            }
            @{
                Position = 'before trivia containing a comma'
                Source = 'param([Parameter(Mandatory=$false <# keep, this #>, Position=0)] [string] $Name)'
                Expected = 'param([Parameter( <# keep, this #> Position=0)] [string] $Name)'
            }
        )
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
        $Result[0].RuleName | Should -Be 'AvoidParameterAttributeBool'
        $Result[0].Severity | Should -Be 'Information'
        $Result[0].RuleSuppressionId | Should -Be 'AvoidParameterAttributeBool'
        $Result[0].Message | Should -Be 'Avoid assigning Boolean values to Parameter attribute arguments'
    }

    It 'Does not report an omitted attribute expression' -ForEach @(
        $SupportedAttributes | ForEach-Object { @{ AttributeName = $_ } }
    ) {
        $ScriptBlockAst = [scriptblock]::create("
            param(
                [Parameter($AttributeName)]
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

    It 'safely removes a false argument in the <Position> position' -ForEach $FalseArgumentCases {
        $ScriptBlockAst = [scriptblock]::Create($Source).Ast
        $Rule = New-Nitpick -Callable Test-AvoidParameterAttributeBool
        $Findings = $Rule.Invoke($ScriptBlockAst)

        $Result = Resolve-NitpickCorrection `
            -Script $Source `
            -Finding $Findings `
            -Rule $Rule

        $Result.RenderedText | Should -Be $Expected
        $Result.Corrections.Accepted | Should -HaveCount 1
        $Result.Findings.Final | Should -HaveCount 0
    }
}
