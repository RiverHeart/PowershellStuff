using namespace System.Management.Automation.Language

Describe 'Complete-WPFEvent' -Tag 'Complete-WPFEvent' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            $script:WPFControlEventsCache = $null
        }

        $script:EventNames = @('AclEvent', 'Click', 'Closed', 'XclTail')

        $script:Source = "Button 'SortProbe' { }"
        $script:Tokens = $null
        $script:ParseErrors = $null
        $script:Ast = [Parser]::ParseInput($script:Source, [ref] $script:Tokens, [ref] $script:ParseErrors)
        $script:CursorOffset = $script:Source.IndexOf('Button') + 1

        Mock -ModuleName WPF -CommandName Get-PSCallStack -MockWith {
            @(
                [pscustomobject]@{
                    Command = 'TabExpansion2'
                    InvocationInfo = [pscustomobject]@{
                        BoundParameters = [pscustomobject]@{
                            Ast = $script:Ast
                            PositionOfCursor = [pscustomobject]@{ Offset = $script:CursorOffset }
                        }
                    }
                }
            )
        }

        Mock -ModuleName WPF -CommandName Get-WPFTypeInfo -MockWith {
            $TypeInfo = [pscustomobject]@{}
            $TypeInfo | Add-Member -MemberType ScriptMethod -Name GetEvents -Value {
                @($script:EventNames | ForEach-Object { [pscustomobject]@{ Name = $_ } })
            }
            $TypeInfo
        }
    }

    It 'Should sort alphabetically when no word is provided' {
        $Result = Complete-WPFEvent -WordToComplete ''

        @($Result.ListItemText) | Should -Be @('AclEvent', 'Click', 'Closed', 'XclTail')
    }

    It 'Should prioritize StartsWith matches when a word is provided' {
        $Result = Complete-WPFEvent -WordToComplete 'cl'

        @($Result.ListItemText) | Should -Be @('Click', 'Closed', 'AclEvent', 'XclTail')
    }
}
