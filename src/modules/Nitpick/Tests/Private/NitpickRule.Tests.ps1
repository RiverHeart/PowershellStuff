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
        $Rule.DispatchType | Should -Be ([AstDocument])
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

    It 'dispatches typed ScriptBlockAst parameters under their declared name' {
        $Rule = New-Nitpick -Name TypedAst -Source Tests -Callable {
            param(
                [System.Management.Automation.Language.ScriptBlockAst] $InputObject
            )
            $InputObject
        }
        $Ast = { '$value' }.Ast

        $Result = @($Rule.Invoke($Ast))[0]

        $Rule.DispatchType | Should -Be ([System.Management.Automation.Language.ScriptBlockAst])
        $Rule.DispatchParameterName | Should -BeExactly 'InputObject'
        [object]::ReferenceEquals($Result, $Ast) | Should -BeTrue
    }

    It 'preserves the legacy ScriptBlockAst name fallback for untyped and object parameters' {
        foreach ($Callable in @(
            { param ($ScriptBlockAst) $ScriptBlockAst },
            { param ([object] $ScriptBlockAst) $ScriptBlockAst }
        )) {
            $Rule = New-Nitpick -Name LegacyAst -Source Tests -Callable $Callable
            $Ast = { '$value' }.Ast

            $Result = @($Rule.Invoke($Ast))[0]

            $Rule.DispatchType | Should -Be ([System.Management.Automation.Language.ScriptBlockAst])
            [object]::ReferenceEquals($Result, $Ast) | Should -BeTrue
        }
    }

    It 'rejects incompatible types declared on the legacy parameter name' {
        {
            New-Nitpick -Name InvalidAst -Source Tests -Callable {
                param ([string] $ScriptBlockAst)
            }
        } | Should -Throw "*Parameter 'ScriptBlockAst'*"
    }

    It 'rejects callable parameters outside the dispatch, Context, and Details contract' {
        {
            New-Nitpick -Name ExtraParameter -Source Tests -Callable {
                param (
                    [System.Management.Automation.Language.ScriptBlockAst] $InputObject,
                    [string] $Configuration
                )
            }
        } | Should -Throw "*Unsupported parameter 'Configuration'*"
    }

    It 'rejects Context parameters that cannot bind with the dispatch parameter' {
        {
            New-Nitpick -Name SeparateContextSet -Source Tests -Callable {
                [CmdletBinding()]
                param(
                    [Parameter(Mandatory,ParameterSetName='Rule')]
                    [System.Management.Automation.Language.ScriptBlockAst] $InputObject,

                    [Parameter(ParameterSetName='Context')]
                    [System.Collections.IDictionary] $Context
                )
            }
        } | Should -Throw '*Context and the dispatch parameter must share an ordinary parameter set*'
    }

    It 'requires Details to be mandatory in its own parameter set' {
        {
            New-Nitpick -Name OptionalDetails -Source Tests -Callable {
                [CmdletBinding(DefaultParameterSetName='Rule')]
                param(
                    [Parameter(Mandatory,ParameterSetName='Rule')]
                    [System.Management.Automation.Language.ScriptBlockAst] $InputObject,

                    [Parameter(ParameterSetName='Details')]
                    [switch] $Details
                )
            }
        } | Should -Throw '*Details must be mandatory in one separate parameter set*'
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
