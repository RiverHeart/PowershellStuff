using namespace System.Management.Automation.Language

Describe 'Complete-WPFState' -Tag 'Complete-WPFState' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    BeforeEach {
        $script:Source = {
            Window 'SortProbe' {
                State @{
                    WindowOnly = 'WindowOnly'
                    Shared = 'Window'
                    MyShared = 'Window'
                }

                Button 'InnerButton' {
                    State @{
                        ButtonOnly = 'ButtonOnly'
                        Shared = 'Button'
                    }

                    When 'Loaded' { }
                }
            }
        }.ToString()
        $script:Tokens = $null
        $script:ParseErrors = $null
        $script:Ast = [Parser]::ParseInput($script:Source, [ref] $script:Tokens, [ref] $script:ParseErrors)
        $script:CursorOffset = $script:Source.IndexOf("When 'Loaded'") + 1

        # Simulate being called from TabExpansion2 with the AST and cursor
        # position in the relevant command
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
    }

    It 'extracts state keys from State declarations in the nested command path' {
        $Result = InModuleScope WPF {
            Complete-WPFState -WordToComplete ''
        }

        @($Result.ListItemText) | Should -Be @('ButtonOnly', 'MyShared', 'Shared', 'WindowOnly')
    }

    It 'prioritizes StartsWith matches when a word is provided' {
        $Result = InModuleScope WPF {
            Complete-WPFState -WordToComplete 'sh'
        }

        @($Result.ListItemText) | Should -Be @('Shared', 'MyShared')
    }
}
