using namespace System.Management.Automation
using namespace System.Management.Automation.Language

Describe 'Complete-WPFThis' -Tag 'Complete-WPFThis' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            $script:WPFThisCompletionCache = $null
        }

        Mock -ModuleName WPF -CommandName Get-WPFTypeInfo -MockWith {
            param([string] $Name)

            if ($Name -ieq 'Button') {
                return [pscustomobject]@{} | Add-Member -MemberType ScriptMethod -Name GetProperties -Value {
                    @(
                        [pscustomobject]@{ Name = 'Content' }
                        [pscustomobject]@{ Name = 'ContextMenu' }
                        [pscustomobject]@{ Name = 'Width' }
                    )
                } -PassThru
            }

            if ($Name -ieq 'Window') {
                return [pscustomobject]@{} | Add-Member -MemberType ScriptMethod -Name GetProperties -Value {
                    @(
                        [pscustomobject]@{ Name = 'Title' }
                        [pscustomobject]@{ Name = 'Top' }
                    )
                } -PassThru
            }

            return $null
        }
    }

    It 'completes $this property names by prefix inside control script blocks' {
        $source = @"
Window 'Main' {
    Button 'SaveButton' {
        `$this.Co
    }
}
"@
        $cursorColumn = $source.IndexOf('$this.Co') + 8

        $result = InModuleScope WPF -Parameters @{ Source = $source; CursorColumn = $cursorColumn } {
            param($Source, $CursorColumn)
            Complete-WPFThis -inputScript $Source -cursorColumn $CursorColumn
        }

        @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText) | Should -Be @('$this.Content', '$this.ContextMenu')
        @($result.CompletionMatches | Select-Object -ExpandProperty ListItemText) | Should -Be @('Content', 'ContextMenu')
    }

    It 'resolves to nearest control command when inside nested non-control commands' {
        $source = @"
Window 'Main' {
    Button 'SaveButton' {
        SomeFunction `$this.Co
    }
}
"@
        $cursorColumn = $source.IndexOf('$this.Co') + 8

        $result = InModuleScope WPF -Parameters @{ Source = $source; CursorColumn = $cursorColumn } {
            param($Source, $CursorColumn)
            Complete-WPFThis -inputScript $Source -cursorColumn $CursorColumn
        }

        @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText) | Should -Be @('$this.Content', '$this.ContextMenu')
    }

    It 'maps App control context to Window properties' {
        $source = @"
App 'MainApp' {
    `$this.Ti
}
"@
        $cursorColumn = $source.IndexOf('$this.Ti') + 8

        $result = InModuleScope WPF -Parameters @{ Source = $source; CursorColumn = $cursorColumn } {
            param($Source, $CursorColumn)
            Complete-WPFThis -inputScript $Source -cursorColumn $CursorColumn
        }

        @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText) | Should -Be @('$this.Title')
    }

    It 'returns no completions when cursor is not typing a this member access' {
        $result = InModuleScope WPF {
            Complete-WPFThis -inputScript "Label 'Foo' { Co }" -cursorColumn 17
        }

        $result | Should -Be $null
    }

    It 'resolves nearest control at this-member boundary offsets' {
        $source = @"
App 'MainApp' {
    Label 'Status' {
        `$this.
    }
}
"@

        $tokens = $null
        $errors = $null
        $ast = [Parser]::ParseInput($source, [ref] $tokens, [ref] $errors)
        $cursorOffset = $source.IndexOf('$this.') + 6

        $result = InModuleScope WPF -Parameters @{ Ast = $ast; CursorOffset = $cursorOffset } {
            param($Ast, $CursorOffset)
            Resolve-WPFControlCommandAstAtCursor -Ast $Ast -CursorOffset $CursorOffset
        }

        $result | Should -Not -Be $null
        $result.GetCommandName() | Should -Be 'Label'

        $nextOffsetResult = InModuleScope WPF -Parameters @{ Ast = $ast; CursorOffset = $cursorOffset } {
            param($Ast, $CursorOffset)
            Resolve-WPFControlCommandAstAtCursor -Ast $Ast -CursorOffset ($CursorOffset + 1)
        }

        $nextOffsetResult | Should -Not -Be $null
        $nextOffsetResult.GetCommandName() | Should -Be 'Label'
    }
}
