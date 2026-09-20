BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CallableParameter' {
    It 'returns parameter AST objects for a scriptblock' {
        $Parameters = @(InModuleScope Nitpick {
            Get-CallableParameter -TargetCallable {
                param ($ScriptBlockAst, $FilePath)
            }
        })

        $Parameters.Count | Should -Be 2
        $Parameters[0] | Should -BeOfType [System.Management.Automation.Language.ParameterAst]
    }

    It 'returns scriptblock parameter names when Name is specified' {
        $Names = @(InModuleScope Nitpick {
            Get-CallableParameter -TargetCallable {
                param ($ScriptBlockAst, $FilePath)
            } -Name
        })

        $Names | Should -Be @('ScriptBlockAst', 'FilePath')
    }

    It 'returns command parameter names' {
        $Names = @(InModuleScope Nitpick {
            $Callable = Get-Command -Name Get-ChildItem -CommandType Cmdlet
            Get-CallableParameter -TargetCallable $Callable -Name
        })

        $Names | Should -Contain 'Path'
        $Names | Should -Contain 'Recurse'
    }

    It 'returns no parameters for a parameterless scriptblock' {
        $Parameters = @(InModuleScope Nitpick {
            Get-CallableParameter -TargetCallable { 'value' } -Name
        })

        $Parameters.Count | Should -Be 0
    }
}
