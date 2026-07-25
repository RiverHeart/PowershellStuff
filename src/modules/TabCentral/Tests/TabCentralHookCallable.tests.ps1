BeforeAll {
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

Describe 'Get-TabCentralHookCallableParameterName' {
    It 'returns declared scriptblock parameter names' {
        $Names = InModuleScope TabCentral {
            Get-TabCentralHookCallableParameterName -TargetCallable {
                param ($First, $Second)
            }
        }

        $Names | Should -Be @('First', 'Second')
    }

    It 'returns an empty array for a scriptblock without a param block' {
        $Names = InModuleScope TabCentral {
            @(Get-TabCentralHookCallableParameterName -TargetCallable { 'value' })
        }

        $Names.Count | Should -Be 0
    }

    It 'returns parameter names from command info' {
        $Names = InModuleScope TabCentral {
            $Callable = Get-Command -Name TabExpansion2 -CommandType Function
            Get-TabCentralHookCallableParameterName -TargetCallable $Callable
        }

        $Names | Should -Contain 'inputScript'
        $Names | Should -Contain 'cursorColumn'
    }
}

Describe 'Assert-TabCentralHookCallableSignature' {
    It 'accepts callable signatures required by each hook type' {
        {
            InModuleScope TabCentral {
                Assert-TabCentralHookCallableSignature -HookType Completer -TargetCallable {
                    param ($inputScript, $cursorColumn, $ast, $tokens, $positionOfCursor, $options)
                }
                Assert-TabCentralHookCallableSignature -HookType Modifier -TargetCallable {
                    param ($CommandCompletion)
                }
            }
        } | Should -Not -Throw
    }

    It 'identifies all missing completer parameters in its error' {
        {
            InModuleScope TabCentral {
                Assert-TabCentralHookCallableSignature -HookType Completer -TargetCallable {
                    param ($inputScript)
                }
            }
        } | Should -Throw '*Missing required parameter(s): cursorColumn, ast, tokens, positionOfCursor, options*'
    }

    It 'includes the command name in a command callable error' {
        {
            InModuleScope TabCentral {
                $Callable = Get-Command -Name Get-ChildItem -CommandType Cmdlet
                Assert-TabCentralHookCallableSignature -HookType Modifier -TargetCallable $Callable
            }
        } | Should -Throw "*Invalid Modifier hook callable 'Get-ChildItem'*"
    }
}
