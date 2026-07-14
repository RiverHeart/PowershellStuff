BeforeAll {
    Remove-Variable -Name TabCentralEnabled -Scope Global -ErrorAction SilentlyContinue
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\TabCentral.psd1'
    Import-Module -Name $ModulePath -Force
}

Describe 'TabCentral core behavior' {
    It 'exports expected public commands' {
        $ExpectedCommands = @(
            'Disable-TabCentral'
            'Enable-TabCentral'
            'Get-TabCentralHook'
            'Register-TabCentralHook'
            'Reset-TabExpansion2'
            'TabExpansion2'
            'Unregister-TabCentralHook'
        )

        foreach ($ExpectedCommand in $ExpectedCommands) {
            Get-Command -Name $ExpectedCommand -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    It 'defaults TabCentral to disabled if not preconfigured' {
        $global:TabCentralEnabled | Should -BeFalse
    }

    It 'allows explicit enable and disable' {
        Disable-TabCentral | Out-Null
        $global:TabCentralEnabled | Should -BeFalse

        Enable-TabCentral | Out-Null
        $global:TabCentralEnabled | Should -BeTrue

        Disable-TabCentral | Out-Null
        $global:TabCentralEnabled | Should -BeFalse
    }

    It 'supports hook registration and discovery' {
        Reset-TabExpansion2

        Register-TabCentralHook -Name 'TestCompleter' -Type Completer -ScriptBlock {
            param(
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )
            return $null
        } -Force

        $Hooks = Get-TabCentralHook -Type Completer -Name 'TestCompleter'
        $Hooks | Should -Not -BeNullOrEmpty
        @($Hooks).Count | Should -Be 1
        @($Hooks)[0].Name | Should -Be 'TestCompleter'

        Unregister-TabCentralHook -Name 'TestCompleter' -Type Completer
        (Get-TabCentralHook -Type Completer -Name 'TestCompleter') | Should -BeNullOrEmpty
    }

    It 'returns CommandCompletion in disabled and enabled modes' {
        Disable-TabCentral | Out-Null
        $DisabledResult = TabExpansion2 -inputScript 'Get-Item ' -cursorColumn 9
        $DisabledResult | Should -BeOfType ([System.Management.Automation.CommandCompletion])

        Enable-TabCentral | Out-Null
        $EnabledResult = TabExpansion2 -inputScript 'Get-Item ' -cursorColumn 9
        $EnabledResult | Should -BeOfType ([System.Management.Automation.CommandCompletion])

        Disable-TabCentral | Out-Null
    }
}
