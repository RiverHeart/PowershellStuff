BeforeAll {
    $script:SavedGlobalTabExpansion = Get-Item -Path Function:\global:TabExpansion2 -ErrorAction SilentlyContinue
    $script:SavedTabCentralEnabled = Get-Variable -Name TabCentralEnabled -Scope Global -ErrorAction SilentlyContinue
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

AfterAll {
    if ($script:SavedGlobalTabExpansion) {
        Set-Item -Path Function:\global:TabExpansion2 -Value $script:SavedGlobalTabExpansion.ScriptBlock -Force
    } else {
        Remove-Item -Path Function:\global:TabExpansion2 -ErrorAction SilentlyContinue
    }

    if ($script:SavedTabCentralEnabled) {
        $global:TabCentralEnabled = $script:SavedTabCentralEnabled.Value
    } else {
        Remove-Variable -Name TabCentralEnabled -Scope Global -ErrorAction SilentlyContinue
    }
}

Describe 'TabCentral enabled state' {
    It 'enables TabCentral globally' {
        Disable-TabCentral

        Enable-TabCentral

        $global:TabCentralEnabled | Should -BeTrue
    }

    It 'disables TabCentral globally' {
        Enable-TabCentral

        Disable-TabCentral

        $global:TabCentralEnabled | Should -BeFalse
    }
}

Describe 'Reset-TabExpansion2' {
    BeforeEach {
        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters['TestCompleter'] = 'completer'
            $Registry.ResultModifiers['TestModifier'] = 'modifier'
        }
    }

    It 'clears all registered hooks' {
        Reset-TabExpansion2

        InModuleScope TabCentral {
            $Registry = Get-TabCentralRegistry
            $Registry.TabCompleters.Count | Should -Be 0
            $Registry.ResultModifiers.Count | Should -Be 0
        }
    }

    It 'returns the empty hook collection when PassThru is specified' {
        $Hooks = @(Reset-TabExpansion2 -PassThru)

        $Hooks.Count | Should -Be 0
    }

    It 'restores the captured original TabExpansion2 function when requested' {
        $Result = InModuleScope TabCentral {
            $SavedOriginal = $script:OriginalTabExpansion2
            try {
                $script:OriginalTabExpansion2 = { 'original-tab-expansion' }
                Set-Item -Path Function:\global:TabExpansion2 -Value { 'replacement-tab-expansion' } -Force

                Reset-TabExpansion2 -RestoreOriginal
                & ${Function:Global:TabExpansion2}
            } finally {
                $script:OriginalTabExpansion2 = $SavedOriginal
            }
        }

        $Result | Should -Be 'original-tab-expansion'
    }
}
