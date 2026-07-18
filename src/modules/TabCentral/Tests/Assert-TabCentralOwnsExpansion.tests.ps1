BeforeAll {
    $script:SavedGlobalTabExpansion = Get-Item -Path Function:\global:TabExpansion2 -ErrorAction SilentlyContinue
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

AfterAll {
    if ($script:SavedGlobalTabExpansion) {
        Set-Item -Path Function:\global:TabExpansion2 -Value $script:SavedGlobalTabExpansion.ScriptBlock -Force
    } else {
        Remove-Item -Path Function:\global:TabExpansion2 -ErrorAction SilentlyContinue
    }
}

Describe 'Assert-TabCentralOwnsExpansion' {
    It 'does not throw when the target TabExpansion2 script block is TabCentral owned' {
        $ModuleTabExpansion = InModuleScope TabCentral {
            $script:TabCentralTabExpansion2
        }

        {
            InModuleScope TabCentral {
                Assert-TabCentralOwnsExpansion -TargetScriptBlock $ModuleTabExpansion
            }
        } | Should -Not -Throw
    }

    It 'throws when the target TabExpansion2 script block is not TabCentral owned' {
        $NonTabCentralTabExpansion = {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [hashtable] $options
            )
            [System.Management.Automation.CommandCompletion]::CompleteInput($inputScript, $cursorColumn, $options)
        }

        {
            InModuleScope TabCentral {
                Assert-TabCentralOwnsExpansion -TargetScriptBlock $NonTabCentralTabExpansion
            }
        } | Should -Throw
    }
}
