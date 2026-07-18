BeforeAll {
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

Describe 'Register-TabCentralHook' {
    BeforeEach {
        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters.Clear()
            $Registry.ResultModifiers.Clear()
        }
    }

    It 'registers a completer hook in the tab completer registry' {
        Register-TabCentralHook -Type Completer -Name TestCompleter -Source Tests -Callable {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )
        }

        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters.ContainsKey('TestCompleter') | Should -BeTrue
            $Registry.TabCompleters['TestCompleter'].Type | Should -Be 'Completer'
        }
    }

    It 'registers a modifier hook in the result modifier registry' {
        Register-TabCentralHook -Type Modifier -Name TestModifier -Source Tests -Callable {
            param (
                [System.Management.Automation.CommandCompletion] $CommandCompletion
            )
        }

        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.ResultModifiers.ContainsKey('TestModifier') | Should -BeTrue
            $Registry.ResultModifiers['TestModifier'].Type | Should -Be 'Modifier'
        }
    }

    It 'throws when registering a duplicate hook without Force' {
        Register-TabCentralHook -Type Completer -Name TestCompleter -Source Tests -Callable {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )
        }

        {
            Register-TabCentralHook -Type Completer -Name TestCompleter -Source Tests -Callable {
                param (
                    [string] $inputScript,
                    [int] $cursorColumn,
                    [System.Management.Automation.Language.Ast] $ast,
                    [System.Management.Automation.Language.Token[]] $tokens,
                    [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                    [hashtable] $options
                )
            } -ErrorAction Stop
        } | Should -Throw
    }

    It 'replaces an existing hook when Force is specified' {
        Register-TabCentralHook -Type Completer -Name TestCompleter -Source Tests -Callable {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )
            'old'
        }

        Register-TabCentralHook -Type Completer -Name TestCompleter -Source Tests -Callable {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )
            'new'
        } -Force

        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters['TestCompleter'].Callable | Should -Not -BeNullOrEmpty
        }
    }

    It 'returns the registered hook when PassThru is specified' {
        $Hook = Register-TabCentralHook -Type Modifier -Name TestModifier -Source Tests -Callable {
            param (
                [System.Management.Automation.CommandCompletion] $CommandCompletion
            )
        } -PassThru

        $Hook | Should -Not -BeNullOrEmpty
        $Hook.Name | Should -Be 'TestModifier'
        $Hook.Type | Should -Be 'Modifier'
    }

    It 'throws when the callable signature is invalid' {
        {
            Register-TabCentralHook -Type Completer -Name InvalidHook -Source Tests -Callable {
                param (
                    [string] $inputScript
                )
            } -ErrorAction Stop
        } | Should -Throw
    }
}
