BeforeAll {
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

Describe 'Get-TabCentralRegistry' {
    BeforeEach {
        InModuleScope TabCentral {
            Remove-Variable -Name TabExpansionRegistry -Scope Script -ErrorAction SilentlyContinue
        }
    }

    It 'initializes both hook tables when the registry does not exist' {
        $Registry = InModuleScope TabCentral {
            Get-TabCentralRegistry
        }

        $Registry | Should -BeOfType ([System.Collections.Specialized.OrderedDictionary])
        $Registry.TabCompleters | Should -BeOfType ([hashtable])
        $Registry.ResultModifiers | Should -BeOfType ([hashtable])
    }

    It 'returns the existing registry without discarding hooks' {
        $Registry = InModuleScope TabCentral {
            $script:TabExpansionRegistry = [ordered] @{
                TabCompleters = @{
                    Existing = 'hook'
                }
                ResultModifiers = @{}
            }

            Get-TabCentralRegistry
        }

        $Registry.TabCompleters.Existing | Should -Be 'hook'
    }

    It 'repairs missing hook tables in an existing registry' {
        $Registry = InModuleScope TabCentral {
            $script:TabExpansionRegistry = [ordered] @{
                OtherState = $true
            }

            Get-TabCentralRegistry
        }

        $Registry.TabCompleters | Should -BeOfType ([hashtable])
        $Registry.ResultModifiers | Should -BeOfType ([hashtable])
        $Registry.OtherState | Should -BeTrue
    }
}
