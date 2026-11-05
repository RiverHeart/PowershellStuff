using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'New-AstDocument' {
    It 'parses string input via InputObject' {
        $Overlay = New-AstDocument -InputObject 'Window Main { }'

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.OriginalText | Should -Be 'Window Main { }'
        $Overlay.Path | Should -Be '<memory>'
    }

    It 'wraps ScriptBlock input passed via InputObject' {
        $Overlay = New-AstDocument -InputObject {
            function Get-Greeting { 'hello' }
        }
        $Functions = @($Overlay.Ast.FindAll({
                    param($Node)
                    $Node -is [FunctionDefinitionAst]
                }, $true))

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.Ast.Extent.StartOffset | Should -BeGreaterThan 0
        $Overlay.IsFragment | Should -BeTrue
        $Overlay.Root.Ast.Extent.StartOffset | Should -Be 0
        $Functions.Name | Should -Be 'Get-Greeting'
    }

    It 'wraps Ast input passed via InputObject' {
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput("Window Main { }", [ref] $Tokens, [ref] $Errors)

        $Overlay = New-AstDocument -InputObject $Ast

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.Ast | Should -Not -Be $Ast
        $Overlay.Ast.Extent.StartOffset | Should -Be 0
        $Overlay.OriginalText | Should -Be 'Window Main { }'
    }

    It 'populates tokens, parse errors, and newline style for ScriptBlock input' {
        $Source = [scriptblock]::Create("`$Value = 1`r`n")

        $Overlay = New-AstDocument -InputObject $Source

        [object]::ReferenceEquals($Overlay.Ast, $Source.Ast) | Should -BeFalse
        $Overlay.Tokens.Count | Should -BeGreaterThan 0
        @($Overlay.ParseErrors) | Should -HaveCount 0
        $Overlay.NewLineSequence | Should -BeExactly "`r`n"
        $Overlay.OriginalFingerprint | Should -Be (
            New-AstDocument -InputObject $Source.Ast.Extent.Text
        ).OriginalFingerprint
    }

    It 'returns parse errors instead of throwing for invalid string input' {
        $Overlay = New-AstDocument -InputObject 'if ('

        $Overlay.Ast | Should -Not -BeNullOrEmpty
        $Overlay.Tokens.Count | Should -BeGreaterThan 0
        $Overlay.ParseErrors.Count | Should -BeGreaterThan 0
        $Overlay.OriginalText | Should -BeExactly 'if ('
    }

    It 'accepts empty source text' {
        $Overlay = New-AstDocument -InputObject ''

        $Overlay.OriginalText | Should -BeExactly ''
        ($null -ne $Overlay.Ast) | Should -BeTrue
        @($Overlay.ParseErrors) | Should -HaveCount 0
    }

    It 'reparses nested file AST input in its snapshot without enabling saves' {
        $Path = Join-Path $TestDrive 'Nested.ps1'
        $Text = "# preceding line`r`n& { `$Value = 1 }"
        [System.IO.File]::WriteAllText($Path, $Text)
        $Tokens = $null
        $Errors = $null
        $Root = [Parser]::ParseFile($Path, [ref] $Tokens, [ref] $Errors)
        $Nested = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock

        $Overlay = New-AstDocument -InputObject $Nested

        $Nested.Extent.StartOffset | Should -BeGreaterThan 0
        $Overlay.Ast.Extent.StartOffset | Should -Be $Nested.Extent.StartOffset
        $Overlay.Ast.Extent.StartLineNumber | Should -Be 2
        $Overlay.Ast.Extent.File | Should -Be $Path
        $Overlay.OriginalText | Should -BeExactly $Text
        $Overlay.IsFragment | Should -BeTrue
        $Overlay.Path | Should -Be '<memory>'
        $Overlay.IsFileBacked | Should -BeFalse
        $Overlay.Root.Ast.Extent.Text | Should -BeExactly $Text
        [object]::ReferenceEquals($Overlay.Ast, $Overlay.Root.Ast) | Should -BeFalse
        $Assignment = $Overlay.Ast.Find({
            param($Node)
            $Node -is [AssignmentStatementAst]
        }, $true)
        $Overlay.Replace($Assignment, '$Value = 2', 'Replace value')
        $Overlay.Render() | Should -BeExactly "# preceding line`r`n& { `$Value = 2 }"
    }

    It 'initializes file input with source-path tokens and a transactional snapshot' {
        $Path = Join-Path $TestDrive 'Source.ps1'
        $Text = "`$Value = 1`r`n"
        [System.IO.File]::WriteAllText($Path, $Text)

        $Overlay = New-AstDocument -Path $Path

        $Overlay.Path | Should -Be $Path
        $Overlay.IsFileBacked | Should -BeTrue
        $Overlay.Ast.Extent.File | Should -Be $Path
        $Overlay.Tokens[0].Extent.File | Should -Be $Path
        @($Overlay.ParseErrors) | Should -HaveCount 0
        $Overlay.NewLineSequence | Should -BeExactly "`r`n"
        $Overlay.OriginalText | Should -BeExactly $Text
    }

    It 'preserves original coordinates on fragment boundaries and assignments: <Label>' -ForEach @(
        @{ Label = 'same-line LF'; NewLine = "`n"; Body = ' $Value = 1 ' }
        @{ Label = 'same-line CRLF'; NewLine = "`r`n"; Body = ' $Value = 1 ' }
        @{ Label = 'multiline LF'; NewLine = "`n"; Body = "`n`t`$Value = 1`n" }
        @{ Label = 'multiline CRLF'; NewLine = "`r`n"; Body = "`r`n`t`$Value = 1`r`n" }
    ) {
        $Text = "# prefix${NewLine}& {$Body}"
        $Path = Join-Path $TestDrive 'Coordinates.ps1'
        $Tokens = $null
        $Errors = $null
        $Root = [Parser]::ParseInput($Text, $Path, [ref] $Tokens, [ref] $Errors)
        $Nested = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock
        $OriginalAssignment = $Nested.Find({
            param($Node)
            $Node -is [AssignmentStatementAst]
        }, $true)

        foreach ($Input in @($Nested, $Nested.GetScriptBlock())) {
            $Overlay = New-AstDocument -InputObject $Input
            $Assignment = $Overlay.Ast.Find({
                param($Node)
                $Node -is [AssignmentStatementAst]
            }, $true)

            foreach ($Pair in @(
                @{ Actual = $Overlay.Ast.Extent.StartScriptPosition; Original = $Nested.Extent.StartScriptPosition }
                @{ Actual = $Assignment.Extent.StartScriptPosition; Original = $OriginalAssignment.Extent.StartScriptPosition }
                @{ Actual = $Overlay.Ast.Extent.EndScriptPosition; Original = $Nested.Extent.EndScriptPosition }
            )) {
                $Pair.Actual.File | Should -Be $Path
                $Pair.Actual.Offset | Should -Be $Pair.Original.Offset
                $Pair.Actual.LineNumber | Should -Be $Pair.Original.LineNumber
                $Pair.Actual.ColumnNumber | Should -Be $Pair.Original.ColumnNumber
            }
            $Overlay.IsFileBacked | Should -BeFalse
        }
    }

    It 'keeps string input coordinates without inventing source provenance' {
        $Overlay = New-AstDocument -InputObject "`$Value = 1`n`t`$Other = 2"
        $Assignment = @($Overlay.Ast.FindAll({
            param($Node)
            $Node -is [AssignmentStatementAst]
        }, $true))[1]
        $Position = $Assignment.Extent.StartScriptPosition

        $Position.File | Should -BeNullOrEmpty
        $Position.Offset | Should -Be 12
        $Position.LineNumber | Should -Be 2
        $Position.ColumnNumber | Should -Be 2
        $Overlay.IsFragment | Should -BeFalse
        [object]::ReferenceEquals($Overlay.Ast, $Overlay.Root.Ast) | Should -BeTrue
    }

    It 'returns an existing AstDocument without coercing or reparsing it' {
        $Original = New-AstDocument -InputObject 'function Get-Greeting { ''hello'' }'

        $Resolved = New-AstDocument -InputObject $Original

        $Resolved | Should -Be $Original
    }

    It 'accepts pipeline input via InputObject' {
        $Overlay = 'Window Main { }' | New-AstDocument

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.OriginalText | Should -Be 'Window Main { }'
        $Overlay.Path | Should -Be '<memory>'
    }

    It 'processes every pipeline input object' {
        $Overlays = @('function Get-One {}', 'function Get-Two {}') |
            New-AstDocument

        $Overlays.Count | Should -Be 2
        $Overlays[0].OriginalText | Should -Be 'function Get-One {}'
        $Overlays[1].OriginalText | Should -Be 'function Get-Two {}'
    }
}
