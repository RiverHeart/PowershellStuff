BeforeAll {
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force

    InModuleScope TabCentral {
        function Test-TabCentralValidCompleter {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )
        }

        function Test-TabCentralInvalidCompleter {
            param (
                [string] $inputScript
            )
        }

        function Test-TabCentralValidModifier {
            param (
                [System.Management.Automation.CommandCompletion] $CommandCompletion
            )
        }

        function Test-TabCentralInvalidModifier {
            param (
                [string] $somethingElse
            )
        }
    }
}

AfterAll {
    InModuleScope TabCentral {
        Remove-Item -Path Function:\Test-TabCentralValidCompleter -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Test-TabCentralInvalidCompleter -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Test-TabCentralValidModifier -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\Test-TabCentralInvalidModifier -ErrorAction SilentlyContinue
    }
}

Describe 'New-TabCentralHook callable signature validation' {
    It 'accepts a valid completer scriptblock with TabExpansion2 parameters' {
        $Hook = New-TabCentralHook -Type Completer -Name TestHook -Source Tests -Callable {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )
        }

        $Hook | Should -Not -BeNullOrEmpty
        $Hook.Type | Should -Be 'Completer'
        $Hook.CallableType | Should -Be 'ScriptBlock'
    }

    It 'rejects a completer callable missing required parameters' {
        {
            New-TabCentralHook -Type Completer -Name BadHook -Source Tests -Callable {
                param (
                    [string] $inputScript,
                    [int] $cursorColumn
                )
            } -ErrorAction Stop
        } | Should -Throw
    }

    It 'accepts a valid completer function info callable' {
        $Callable = Get-Command -Name TabExpansion2 -CommandType Function
        $Hook = New-TabCentralHook -Type Completer -Callable $Callable

        $Hook | Should -Not -BeNullOrEmpty
        $Hook.CallableType | Should -Be 'Function'
        $Hook.Callable | Should -Be 'TabExpansion2'
    }

    It 'accepts a valid completer function name string' {
        $Hook = New-TabCentralHook -Type Completer -Callable 'TabExpansion2'

        $Hook | Should -Not -BeNullOrEmpty
        $Hook.CallableType | Should -Be 'Function'
        $Hook.Callable | Should -Be 'TabExpansion2'
    }

    It 'rejects an unknown function name string callable' {
        {
            New-TabCentralHook -Type Completer -Callable 'NoSuchTabCentralCallable' -ErrorAction Stop
        } | Should -Throw
    }

    It 'accepts a valid modifier scriptblock and rejects an invalid cmdlet callable' {
        $ValidHook = New-TabCentralHook -Type Modifier -Name ModifierHook -Source Tests -Callable {
            param (
                [System.Management.Automation.CommandCompletion] $CommandCompletion
            )
        }
        $ValidHook | Should -Not -BeNullOrEmpty
        $ValidHook.Type | Should -Be 'Modifier'

        $InvalidCallable = Get-Command -Name Get-ChildItem -CommandType Cmdlet
        {
            New-TabCentralHook -Type Modifier -Callable $InvalidCallable -Source Tests -ErrorAction Stop
        } | Should -Throw
    }
}
