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

    It 'registers hooks from module PrivateData using an in-memory module' {
        $ModuleName = 'TabCentral.TestProvider'
        $ProviderModule = New-Module -Name $ModuleName -ScriptBlock {
            $ExecutionContext.SessionState.Module.PrivateData = @{
                TabExpansion = @{
                    Completers = @('Complete-TabCentralTestProvider')
                    Modifiers = @('Modify-TabCentralTestProvider')
                }
            }

            function Complete-TabCentralTestProvider {
                param (
                    [string] $inputScript,
                    [int] $cursorColumn,
                    [System.Management.Automation.Language.Ast] $ast,
                    [System.Management.Automation.Language.Token[]] $tokens,
                    [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                    [hashtable] $options
                )
            }

            function Modify-TabCentralTestProvider {
                param (
                    [System.Management.Automation.CommandCompletion] $CommandCompletion
                )

                return $CommandCompletion
            }

            Export-ModuleMember -Function Complete-TabCentralTestProvider, Modify-TabCentralTestProvider
        }

        Import-Module -ModuleInfo $ProviderModule -Force
        try {
            Register-TabCentralHook -Module $ProviderModule

            InModuleScope TabCentral {
                $Registry = Get-TabCentralRegistry
                $Registry.TabCompleters.ContainsKey('Complete-TabCentralTestProvider') | Should -BeTrue
                $Registry.ResultModifiers.ContainsKey('Modify-TabCentralTestProvider') | Should -BeTrue
            }
        } finally {
            Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue
        }
    }

    It 'returns registered hooks from module mode when PassThru is specified' {
        $ModuleName = 'TabCentral.TestProvider.PassThru'
        $ProviderModule = New-Module -Name $ModuleName -ScriptBlock {
            $ExecutionContext.SessionState.Module.PrivateData = @{
                TabExpansion = @{
                    Completers = @('Complete-TabCentralTestProviderPassThru')
                    Modifiers = @('Modify-TabCentralTestProviderPassThru')
                }
            }

            function Complete-TabCentralTestProviderPassThru {
                param (
                    [string] $inputScript,
                    [int] $cursorColumn,
                    [System.Management.Automation.Language.Ast] $ast,
                    [System.Management.Automation.Language.Token[]] $tokens,
                    [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                    [hashtable] $options
                )
            }

            function Modify-TabCentralTestProviderPassThru {
                param (
                    [System.Management.Automation.CommandCompletion] $CommandCompletion
                )

                return $CommandCompletion
            }

            Export-ModuleMember -Function Complete-TabCentralTestProviderPassThru, Modify-TabCentralTestProviderPassThru
        }

        Import-Module -ModuleInfo $ProviderModule -Force
        try {
            $Hooks = @(Register-TabCentralHook -Module $ProviderModule -PassThru)

            $Hooks.Count | Should -Be 2
            @($Hooks.Name) | Should -Contain 'Complete-TabCentralTestProviderPassThru'
            @($Hooks.Name) | Should -Contain 'Modify-TabCentralTestProviderPassThru'
        } finally {
            Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue
        }
    }

    It 'throws on duplicate module registration unless Force is specified' {
        $ModuleName = 'TabCentral.TestProvider.Force'
        $ProviderModule = New-Module -Name $ModuleName -ScriptBlock {
            $ExecutionContext.SessionState.Module.PrivateData = @{
                TabExpansion = @{
                    Completers = @('Complete-TabCentralTestProviderForce')
                    Modifiers = @()
                }
            }

            function Complete-TabCentralTestProviderForce {
                param (
                    [string] $inputScript,
                    [int] $cursorColumn,
                    [System.Management.Automation.Language.Ast] $ast,
                    [System.Management.Automation.Language.Token[]] $tokens,
                    [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                    [hashtable] $options
                )
            }

            Export-ModuleMember -Function Complete-TabCentralTestProviderForce
        }

        Import-Module -ModuleInfo $ProviderModule -Force
        try {
            Register-TabCentralHook -Module $ProviderModule

            {
                Register-TabCentralHook -Module $ProviderModule -ErrorAction Stop
            } | Should -Throw

            {
                Register-TabCentralHook -Module $ProviderModule -Force -ErrorAction Stop
            } | Should -Not -Throw
        } finally {
            Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue
        }
    }

    It 'supports version filtering when module info version matches' {
        $ModuleName = 'TabCentral.TestProvider.Version.Match'
        $ProviderModule = New-Module -Name $ModuleName -ScriptBlock {
            $ExecutionContext.SessionState.Module.PrivateData = @{
                TabExpansion = @{
                    Completers = @('Complete-TabCentralTestProviderVersionMatch')
                    Modifiers = @()
                }
            }

            function Complete-TabCentralTestProviderVersionMatch {
                param (
                    [string] $inputScript,
                    [int] $cursorColumn,
                    [System.Management.Automation.Language.Ast] $ast,
                    [System.Management.Automation.Language.Token[]] $tokens,
                    [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                    [hashtable] $options
                )
            }

            Export-ModuleMember -Function Complete-TabCentralTestProviderVersionMatch
        }

        Import-Module -ModuleInfo $ProviderModule -Force
        try {
            {
                Register-TabCentralHook -Module $ProviderModule -Version $ProviderModule.Version -ErrorAction Stop
            } | Should -Not -Throw

            InModuleScope TabCentral {
                $Registry = Get-TabCentralRegistry
                $Registry.TabCompleters.ContainsKey('Complete-TabCentralTestProviderVersionMatch') | Should -BeTrue
            }
        } finally {
            Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue
        }
    }

    It 'throws when module info version does not match requested version' {
        $ModuleName = 'TabCentral.TestProvider.Version.Mismatch'
        $ProviderModule = New-Module -Name $ModuleName -ScriptBlock {
            $ExecutionContext.SessionState.Module.PrivateData = @{
                TabExpansion = @{
                    Completers = @('Complete-TabCentralTestProviderVersionMismatch')
                    Modifiers = @()
                }
            }

            function Complete-TabCentralTestProviderVersionMismatch {
                param (
                    [string] $inputScript,
                    [int] $cursorColumn,
                    [System.Management.Automation.Language.Ast] $ast,
                    [System.Management.Automation.Language.Token[]] $tokens,
                    [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                    [hashtable] $options
                )
            }

            Export-ModuleMember -Function Complete-TabCentralTestProviderVersionMismatch
        }

        Import-Module -ModuleInfo $ProviderModule -Force
        try {
            {
                Register-TabCentralHook -Module $ProviderModule -Version ([version]'999.0') -ErrorAction Stop
            } | Should -Throw
        } finally {
            Remove-Module -Name $ModuleName -ErrorAction SilentlyContinue
        }
    }
}
