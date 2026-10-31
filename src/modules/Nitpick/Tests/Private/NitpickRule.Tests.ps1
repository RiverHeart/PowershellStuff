BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'NitpickRule' {
    It 'returns no findings when the callable emits no output' {
        InModuleScope Nitpick {
            $Rule = New-Nitpick `
                -Name Test-NoFindingsRule `
                -Source Tests `
                -Callable {
                    [CmdletBinding()]
                    param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)
                }

            $Findings = $Rule.Invoke({}.Ast)

            $Findings.Count | Should -Be 0
        }
    }

    It 'returns NitpickFinding objects when requested' {
        InModuleScope Nitpick {
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator

            $Context = @{
                RuleBehavior = @{ OutputType = 'NitpickFinding' }
            }
            $Findings = $Rule.Invoke({
                -not ($Value -is [string])
            }.Ast, $Context)

            $Findings.Count | Should -Be 1
            $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
        }
    }

    It 'returns DiagnosticRecord objects when requested' {
        InModuleScope Nitpick {
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator
            $Context = @{
                RuleBehavior = @{ OutputType = 'DiagnosticRecord' }
            }
            $Findings = $Rule.Invoke({
                -not ($Value -is [string])
            }.Ast, $Context)

            $Findings.Count | Should -Be 1
            $Findings[0].GetType().Name | Should -Be 'DiagnosticRecord'
        }
    }

    It 'uses native output and nested traversal by default for both built-in rules' {
        InModuleScope Nitpick {
            $Ast = {
                function Test-Value {
                    param([Parameter(Mandatory=$true)] [string] $Name)
                    -not ($Name -is [string])
                }
            }.Ast
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
            $Rule = New-Nitpick -Name ContextRule -Source Tests -Callable {
                [CmdletBinding()]
                param(
                    [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,
                    [System.Collections.IDictionary] $Context
                )
                $Context
            }
            $Context = [ordered]@{ Caller = 'TestHost'; Extra = 'preserved' }
            $Results = $Rule.Invoke({}.Ast, $Context)

            $Results | Should -HaveCount 1
            [object]::ReferenceEquals($Results[0], $Context) | Should -BeTrue
        }
    }

    It 'honors explicit scope-local traversal and native output for another caller' {
        InModuleScope Nitpick {
            $Context = @{
                Caller = 'TestHost'
                RuleBehavior = @{
                    SearchNestedScriptBlocks = $false
                    OutputType = 'NitpickFinding'
                }
            }
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator
            $Findings = $Rule.Invoke({
                -not ($Value -is [string])
                & { -not ($Nested -is [string]) }
            }.Ast, $Context)

            $Findings | Should -HaveCount 1
            $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
        }
    }
}
