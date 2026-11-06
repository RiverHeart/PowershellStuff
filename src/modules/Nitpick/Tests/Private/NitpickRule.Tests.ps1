using module AstEditor

BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'NitpickRule' {
    It 'dispatches an AstDocument directly and keeps it out of Context' {
        #=== Arrange ===#
        $Rule = New-Nitpick -Name DocumentContext -Source Tests -Callable {
            param(
                [AstDocument] $Document,
                [System.Collections.IDictionary] $Context
            )
            [pscustomobject]@{ Document = $Document; Context = $Context }
        }
        $Document = New-AstDocument -InputObject '# text'
        $Context = @{}

        #=== Act ===#
        $Result = @($Rule.Invoke($Document, $Context))[0]

        #=== Assert ===#
        $Rule.DispatchType | Should -BeExactly 'AstDocument'
        [object]::ReferenceEquals($Result.Document, $Document) | Should -BeTrue
        [object]::ReferenceEquals($Result.Context, $Context) | Should -BeTrue
        $Context.Contains('Document') | Should -BeFalse
    }

    It 'supports AstDocument dispatch from AST-only and dictionary invocation' {
        #=== Arrange ===#
        $Rule = New-Nitpick -Name DocumentContext -Source Tests -Callable {
            param(
                [AstDocument] $Document
            )
            $Document
        }
        $Document = New-AstDocument -InputObject '# text'
        $Ast = $Document.Ast

        #=== Act ===#
        $Direct = @($Rule.Invoke($Ast))[0]
        $Dictionary = @($Rule.Invoke(@{ Document = $Document }))[0]

        #=== Assert ===#
        $Direct.OriginalText | Should -BeExactly '# text'
        [object]::ReferenceEquals($Dictionary, $Document) | Should -BeTrue
    }

    It 'rejects callables with more than one dispatch parameter' {
        {
            New-Nitpick -Name Ambiguous -Source Tests -Callable {
                param(
                    [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,
                    [AstDocument] $Document
                )
            }
        } | Should -Throw '*exactly one dispatch parameter*'
    }

    It 'returns no findings when the callable emits no output' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Rule = New-Nitpick `
                -Name Test-NoFindingsRule `
                -Source Tests `
                -Callable {
                    [CmdletBinding()]
                    param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)
                }

            #=== Act ===#
            $Findings = $Rule.Invoke({}.Ast)

            #=== Assert ===#
            $Findings.Count | Should -Be 0
        }
    }

    It 'returns NitpickFinding objects when requested' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator

            $Context = @{
                RuleBehavior = @{ OutputType = 'NitpickFinding' }
            }

            #=== Act ===#
            $Findings = $Rule.Invoke({
                -not ($Value -is [string])
            }.Ast, $Context)

            #=== Assert ===#
            $Findings.Count | Should -Be 1
            $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
        }
    }

    It 'returns DiagnosticRecord objects when requested' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator
            $Context = @{
                RuleBehavior = @{ OutputType = 'DiagnosticRecord' }
            }

            #=== Act ===#
            $Findings = $Rule.Invoke({
                -not ($Value -is [string])
            }.Ast, $Context)

            #=== Assert ===#
            $Findings.Count | Should -Be 1
            $Findings[0].GetType().Name | Should -Be 'DiagnosticRecord'
        }
    }

    It 'uses native output and nested traversal by default for both built-in rules' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Ast = {
                function Test-Value {
                    param([Parameter(Mandatory=$true)] [string] $Name)
                    -not ($Name -is [string])
                }
            }.Ast

            #=== Act & Assert ===#
            foreach ($Command in 'Test-UseIsNotOperator', 'Test-AvoidParameterAttributeBool') {
                $Rule = New-Nitpick -Callable $Command
                $Findings = $Rule.Invoke($Ast)

                $Findings | Should -HaveCount 1
                $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
            }
        }
    }

    It 'passes an ordered context dictionary only to an opted-in callable' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Rule = New-Nitpick -Name ContextRule -Source Tests -Callable {
                [CmdletBinding()]
                param(
                    [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,
                    [System.Collections.IDictionary] $Context
                )
                $Context
            }
            $Context = [ordered]@{ Caller = 'TestHost'; Extra = 'preserved' }

            #=== Act ===#
            $Results = $Rule.Invoke({}.Ast, $Context)

            #=== Assert ===#
            $Results | Should -HaveCount 1
            [object]::ReferenceEquals($Results[0], $Context) | Should -BeTrue
        }
    }

    It 'honors explicit scope-local traversal and native output for another caller' {
        InModuleScope Nitpick {
            #=== Arrange ===#
            $Context = @{
                Caller = 'TestHost'
                RuleBehavior = @{
                    SearchNestedScriptBlocks = $false
                    OutputType = 'NitpickFinding'
                }
            }
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator

            #=== Act ===#
            $Findings = $Rule.Invoke({
                -not ($Value -is [string])
                & { -not ($Nested -is [string]) }
            }.Ast, $Context)

            #=== Assert ===#
            $Findings | Should -HaveCount 1
            $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
        }
    }
}
