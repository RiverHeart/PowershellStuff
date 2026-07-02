using namespace System.Management.Automation
using namespace System.Management.Automation.Language

Describe 'Complete-WPFThis' -Tag 'Complete-WPFThis' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            $script:WPFThisCompletionCache = $null
            Unregister-WPFCompletionType -All
        }

        Mock -ModuleName WPF -CommandName Get-WPFTypeInfo -MockWith {
            param([string] $Name)

            if ($Name -ieq 'Button') {
                return [System.Windows.Controls.Button]
            }

            if ($Name -ieq 'Window') {
                return [System.Windows.Window]
            }

            if ($Name -ieq 'Label') {
                return [System.Windows.Controls.Label]
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

        @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText) | Should -Contain '$this.Content'
        @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText) | Should -Contain '$this.ContextMenu'
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

        @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText) | Should -Contain '$this.Content'
    }

    It 'includes method completions by default' {
        $source = @"
Window 'Main' {
    Button 'SaveButton' {
        `$this.Foc
    }
}
"@
        $cursorColumn = $source.IndexOf('$this.Foc') + 9

        $result = InModuleScope WPF -Parameters @{ Source = $source; CursorColumn = $cursorColumn } {
            param($Source, $CursorColumn)
            Complete-WPFThis -inputScript $Source -cursorColumn $CursorColumn
        }

        @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText) | Should -Contain '$this.Focus('
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

        @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText) | Should -Contain '$this.Title'
    }

    It 'supports custom keyword completion via registered completion types' {
        $source = @"
FancyControl 'Custom' {
    `$this.Ti
}
"@
        $cursorColumn = $source.IndexOf('$this.Ti') + 8

        $result = InModuleScope WPF -Parameters @{ Source = $source; CursorColumn = $cursorColumn } {
            param($Source, $CursorColumn)
            Register-WPFCompletionType -Name FancyControl -Type ([System.Windows.Window])
            Complete-WPFThis -inputScript $Source -cursorColumn $CursorColumn
        }

        @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText) | Should -Contain '$this.Title'
    }

    It 'surfaces one method completion entry and includes overloads in the tooltip' {
        $source = @"
StringHost 'Custom' {
    `$this.Subs
}
"@
        $cursorColumn = $source.IndexOf('$this.Subs') + 10

        $result = InModuleScope WPF -Parameters @{ Source = $source; CursorColumn = $cursorColumn } {
            param($Source, $CursorColumn)
            Register-WPFCompletionType -Name StringHost -Type ([System.String])
            Complete-WPFThis -inputScript $Source -cursorColumn $CursorColumn
        }

        $substringCompletions = @($result.CompletionMatches | Where-Object { $_.ListItemText -eq 'Substring()' })
        $substringCompletions.Count | Should -Be 1
        @($substringCompletions[0].ToolTip -split "(`r`n|`n)").Count | Should -BeGreaterThan 1
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
