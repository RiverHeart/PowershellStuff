BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'NitpickRule invocation' {
    It 'returns no findings when the callable emits no output' {
        InModuleScope Nitpick {
            $Rule = New-Nitpick `
                -Name Test-NoFindingsRule `
                -Source Tests `
                -Callable {
                    param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)
                }

            $Findings = $Rule.Invoke({}.Ast)

            $Findings.Count | Should -Be 0
        }
    }

    It 'returns native findings and restores the previous invocation context' {
        InModuleScope Nitpick {
            $Rule = New-Nitpick -Callable Test-AvoidParameterAttributeBool
            $script:NitpickInvocationContext = 'ExistingContext'

            try {
                $Findings = $Rule.Invoke(
                    { param([Parameter(Mandatory=$true)] [string] $Name) }.Ast
                )

                $Findings.Count | Should -Be 1
                $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
                $script:NitpickInvocationContext | Should -Be 'ExistingContext'
            } finally {
                Remove-Variable -Name NitpickInvocationContext -Scope Script
            }
        }
    }

    It 'restores the previous invocation context when a rule throws' {
        InModuleScope Nitpick {
            $Rule = New-Nitpick `
                -Name Test-ThrowingRule `
                -Source Tests `
                -Callable {
                    param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

                    throw 'Rule failed.'
                }
            $script:NitpickInvocationContext = 'ExistingContext'

            try {
                { $Rule.Invoke({}.Ast) } | Should -Throw 'Rule failed.'
                $script:NitpickInvocationContext | Should -Be 'ExistingContext'
            } finally {
                Remove-Variable -Name NitpickInvocationContext -Scope Script
            }
        }
    }
}
