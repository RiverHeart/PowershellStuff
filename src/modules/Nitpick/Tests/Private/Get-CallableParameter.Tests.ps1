BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Get-CallableParameter' {
    It 'returns normalized parameters for a scriptblock' {
        $Parameters = @(InModuleScope Nitpick {
            Get-CallableParameter -Callable {
                param (
                    [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,
                    [string] $FilePath
                )
            }
        })

        $Parameters.Count | Should -Be 2
        $Parameters[0].PSObject.TypeNames | Should -Contain 'Nitpick.CallableParameter'
        $Parameters[0].Name | Should -Be 'ScriptBlockAst'
        $Parameters[0].ParameterType | Should -Be ([System.Management.Automation.Language.ScriptBlockAst])
    }

    It 'filters scriptblock parameters by name' {
        $Parameters = @(InModuleScope Nitpick {
            Get-CallableParameter -Callable {
                param ($ScriptBlockAst, $FilePath)
            } -Name 'Script*'
        })

        $Parameters.Count | Should -Be 1
        $Parameters[0].Name | Should -Be 'ScriptBlockAst'
    }

    It 'returns normalized parameters for a command' {
        $Parameters = @(InModuleScope Nitpick {
            $Callable = Get-Command -Name Get-ChildItem -CommandType Cmdlet
            Get-CallableParameter -Callable $Callable -Name 'Path'
        })

        $Parameters.Count | Should -Be 1
        $Parameters[0].PSObject.TypeNames | Should -Contain 'Nitpick.CallableParameter'
        $Parameters[0].Name | Should -Be 'Path'
        $Parameters[0].ParameterType | Should -Be ([string[]])
    }

    It 'filters parameters by type' {
        $Parameters = @(InModuleScope Nitpick {
            Get-CallableParameter -Callable {
                param ($ScriptBlockAst, [switch] $Details)
            } -Name 'Details' -Type 'SwitchParameter'
        })

        $Parameters.Count | Should -Be 1
        $Parameters[0].Name | Should -Be 'Details'
    }

    It 'returns no parameters for a parameterless scriptblock' {
        $Parameters = @(InModuleScope Nitpick {
            Get-CallableParameter -Callable { 'value' }
        })

        $Parameters.Count | Should -Be 0
    }
}
