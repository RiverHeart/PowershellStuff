using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Show-AstDiff' {
    It 'preserves blank changed and context lines with <Name> terminators' -ForEach @(
        @{ Name = 'LF'; NewLine = "`n" }
        @{ Name = 'CRLF'; NewLine = "`r`n" }
        @{ Name = 'CR'; NewLine = "`r" }
    ) {
        $Source = "${NewLine}one${NewLine}${NewLine}two${NewLine}${NewLine}"
        $Document = New-AstDocument -InputObject $Source
        $Start = $Source.IndexOf('one')
        $End = $Source.IndexOf('two') + 3
        $Document.ReplaceRange($Start, $End, "ONE${NewLine}${NewLine}TWO", 'Change')

        $Output = @(Show-AstDiff -Document $Document -Context 1 -NoColor)

        $Output.Count | Should -Be 1
        $Output[0] | Should -BeExactly ((@(
            '[0] Change',
            '  1 |   ',
            '  2 | - one',
            '  3 | - ',
            '  4 | - two',
            '    | + ONE',
            '    | + ',
            '    | + TWO',
            '  5 |   '
        )) -join [Environment]::NewLine)
    }

    Describe 'Show-AstDiff caret annotations' {
        It 'annotates <Name> only on its nonempty sides' -ForEach @(
            @{
                Name = 'insertion'; Start = 14; End = 14; Replacement = ' world'
                Expected = @(
                    '[0] Change',
                    '  1 | - $name = "hello"',
                    '    | + $name = "hello world"',
                    '    |                 ^^^^^^'
                )
            }
            @{
                Name = 'deletion'; Start = 9; End = 14; Replacement = ''
                Expected = @(
                    '[0] Change',
                    '  1 | - $name = "hello"',
                    '    |            ^^^^^',
                    '    | + $name = ""'
                )
            }
            @{
                Name = 'replacement'; Start = 9; End = 14; Replacement = 'hi'
                Expected = @(
                    '[0] Change',
                    '  1 | - $name = "hello"',
                    '    |            ^^^^^',
                    '    | + $name = "hi"',
                    '    |            ^^'
                )
            }
        ) {
            $Document = New-AstDocument -InputObject '$name = "hello"'
            $Document.ReplaceRange($Start, $End, $Replacement, 'Change')

            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly ($Expected -join [Environment]::NewLine)
        }

        It 'merges disjoint spans and adjusts later replacements after a length change' {
            $Document = New-AstDocument -InputObject 'abc def ghi'
            $Document.ReplaceRange(8, 11, 'GHI!!', 'Last')
            $Document.ReplaceRange(0, 3, 'A', 'First')

            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0] First',
                    '[1] Last',
                    '  1 | - abc def ghi',
                    '    |   ^^^     ^^^',
                    '    | + A def GHI!!',
                    '    |   ^     ^^^^^'
                ) -join [Environment]::NewLine)
        }

        It 'merges adjacent spans without gaps' {
            $Document = New-AstDocument -InputObject 'abcd'
            $Document.ReplaceRange(0, 2, 'X', 'Change')
            $Document.ReplaceRange(2, 4, 'YZ', 'Change')

            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0, 1] Change',
                    '  1 | - abcd',
                    '    |   ^^^^',
                    '    | + XYZ',
                    '    |   ^^^'
                ) -join [Environment]::NewLine)
        }

        It 'keeps repeated reason headers unchanged with Label=<Label>' -ForEach @(
            @{ Label = 'Index'; Header = '[0, 1] Change' }
            @{ Label = 'Position'; Header = '1:1  Change' }
        ) {
            $Document = New-AstDocument -InputObject '-not ($Value -is [int])'
            $Document.ReplaceRange(0, 4, '', 'Change')
            $Document.ReplaceRange(13, 16, '-isnot', 'Change')

            $Diff = Show-AstDiff -Document $Document -Annotate -Label $Label -NoColor
            $Diff | Should -BeExactly (@(
                $Header,
                '  1 | - -not ($Value -is [int])',
                '    |   ^^^^         ^^^',
                '    | +  ($Value -isnot [int])',
                '    |            ^^^^^^'
            ) -join [Environment]::NewLine)
            ($Diff -split '\r?\n' | Where-Object { $_ -notmatch '\^' }) -join [Environment]::NewLine |
                Should -BeExactly (Show-AstDiff -Document $Document -Label $Label -NoColor)
        }

        It 'does not apply unselected edits to replacement span positions' {
            $Document = New-AstDocument -InputObject 'abc def ghi'
            $Document.ReplaceRange(0, 3, 'A', 'First')
            $Document.ReplaceRange(8, 11, 'GHI!!', 'Last')

            Show-AstDiff -Document $Document -Annotate -EditIndex 1,1 -NoColor |
                Should -BeExactly (@(
                    '[1] Last',
                    '  1 | - abc def ghi',
                    '    |           ^^^',
                    '    | + abc def GHI!!',
                    '    |           ^^^^^'
                ) -join [Environment]::NewLine)
        }

        It 'maps replacements after inserted <Name> newlines and annotates only span start lines' -ForEach @(
            @{ Name = 'LF'; NewLine = "`n" }
            @{ Name = 'CRLF'; NewLine = "`r`n" }
            @{ Name = 'CR'; NewLine = "`r" }
        ) {
            $Document = New-AstDocument -InputObject 'aa bb cc'
            $Document.ReplaceRange(0, 2, "A${NewLine}B", 'First')
            $Document.ReplaceRange(6, 8, 'CCC', 'Last')

            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0] First',
                    '[1] Last',
                    '  1 | - aa bb cc',
                    '    |   ^^    ^^',
                    '    | + A',
                    '    |   ^',
                    '    | + B bb CCC',
                    '    |        ^^^'
                ) -join [Environment]::NewLine)
        }

        It 'clips multiline removal spans before <Name> terminators and preserves blank context' -ForEach @(
            @{ Name = 'LF'; NewLine = "`n" }
            @{ Name = 'CRLF'; NewLine = "`r`n" }
            @{ Name = 'CR'; NewLine = "`r" }
        ) {
            $Source = "${NewLine}one${NewLine}${NewLine}two${NewLine}${NewLine}"
            $Document = New-AstDocument -InputObject $Source
            $Document.ReplaceRange($Source.IndexOf('one'), $Source.IndexOf('two') + 3, 'ONE', 'Change')

            Show-AstDiff -Document $Document -Annotate -Context 1 -NoColor |
                Should -BeExactly (@(
                    '[0] Change',
                    '  1 |   ',
                    '  2 | - one',
                    '    |   ^^^',
                    '  3 | - ',
                    '  4 | - two',
                    '    | + ONE',
                    '    |   ^^^',
                    '  5 |   '
                ) -join [Environment]::NewLine)
        }

        It 'annotates an EOF insertion in <Name> without an original-side anchor' -ForEach @(
            @{
                Name = 'empty text'; Source = ''
                Expected = @(
                    '1:1  Append',
                    '    | + MORE',
                    '    |   ^^^^'
                )
            }
            @{
                Name = 'an unterminated line'; Source = 'one'
                Expected = @(
                    '1:4  Append',
                    '  1 | - one',
                    '    | + oneMORE',
                    '    |      ^^^^'
                )
            }
            @{
                Name = 'terminated text'; Source = "one`n"
                Expected = @(
                    '2:1  Append',
                    '  1 |   one',
                    '    | + MORE',
                    '    |   ^^^^'
                )
            }
        ) {
            $Document = New-AstDocument -InputObject $Source
            $Document.Insert($Source.Length, 'MORE', 'Append')

            Show-AstDiff `
                -Document $Document `
                -Annotate `
                -Context 1 `
                -Label Position `
                -NoColor |
                Should -BeExactly ($Expected -join [Environment]::NewLine)
        }

        It 'marks a removed <Name> terminator without underlining the joined replacement' -ForEach @(
            @{ Name = 'LF'; NewLine = "`n" }
            @{ Name = 'CRLF'; NewLine = "`r`n" }
            @{ Name = 'CR'; NewLine = "`r" }
        ) {
            $Document = New-AstDocument -InputObject "one${NewLine}two"
            $Document.ReplaceRange(3, 3 + $NewLine.Length, '', 'Join')

            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0] Join',
                    '  1 | - one',
                    '    |      ^',
                    '  2 | - two',
                    '    | + onetwo'
                ) -join [Environment]::NewLine)
        }

        It 'maps a later replacement into a joined line' {
            $Document = New-AstDocument -InputObject "one`ntwo"
            $Document.ReplaceRange(3, 4, '', 'Join')
            $Document.ReplaceRange(4, 7, 'TWO', 'Uppercase')

            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0] Join',
                    '[1] Uppercase',
                    '  1 | - one',
                    '    |      ^',
                    '  2 | - two',
                    '    |   ^^^',
                    '    | + oneTWO',
                    '    |      ^^^'
                ) -join [Environment]::NewLine)
        }

        It 'marks inserted terminators and removed blank lines as boundaries' {
            $Document = New-AstDocument -InputObject 'one'
            $Document.Insert(3, "`n", 'Terminate')
            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0] Terminate',
                    '  1 | - one',
                    '    | + one',
                    '    |      ^'
                ) -join [Environment]::NewLine)

            $Document = New-AstDocument -InputObject "`none"
            $Document.ReplaceRange(0, 1, '', 'Remove blank')
            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0] Remove blank',
                    '  1 | - ',
                    '    |   ^'
                ) -join [Environment]::NewLine)
        }

        It 'preserves tabs before and between merged spans with a multi-digit gutter' {
            $Source = ("line`n" * 9) + "`tab`tcd"
            $Document = New-AstDocument -InputObject $Source
            $Document.ReplaceRange($Source.IndexOf('ab'), $Source.IndexOf('ab') + 1, 'A', 'Change')
            $Document.ReplaceRange($Source.IndexOf('cd'), $Source.IndexOf('cd') + 1, 'C', 'Change')

            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0, 1] Change',
                    "  10 | - `tab`tcd",
                    "     |   `t^ `t^",
                    "     | + `tAb`tCd",
                    "     |   `t^ `t^"
                ) -join [Environment]::NewLine)
        }

        It 'uses UTF-16 span widths for surrogate pairs rather than display-cell widths' {
            $Source = "x$([char]0xD83D)$([char]0xDE00)z"
            $Document = New-AstDocument -InputObject $Source
            $Document.ReplaceRange(1, 3, 'y', 'Change')

            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0] Change',
                    "  1 | - $Source",
                    '    |    ^^',
                    '    | + xyz',
                    '    |    ^'
                ) -join [Environment]::NewLine)
        }

        It 'retains hunk boundaries and never annotates context' {
            $Document = New-AstDocument -InputObject "one`ntwo`nthree`nfour`nfive"
            $Document.ReplaceRange(4, 7, 'TWO', 'Second')
            $Document.ReplaceRange(19, 23, 'FIVE', 'Fifth')

            Show-AstDiff -Document $Document -Annotate -NoColor |
                Should -BeExactly (@(
                    '[0] Second',
                    '  2 | - two',
                    '    |   ^^^',
                    '    | + TWO',
                    '    |   ^^^',
                    '',
                    '[1] Fifth',
                    '  5 | - five',
                    '    |   ^^^^',
                    '    | + FIVE',
                    '    |   ^^^^'
                ) -join [Environment]::NewLine)
            $Diff = Show-AstDiff -Document $Document -Annotate -Context 1 -NoColor
            ($Diff -split '\r?\n' |
                Where-Object { $_ -notmatch '\^' }) -join [Environment]::NewLine |
                Should -BeExactly (Show-AstDiff -Document $Document -Context 1 -NoColor)
        }

        It 'preserves empty outputs and rejects invalid selections in annotation mode' {
            $Document = New-AstDocument -InputObject 'one'
            @(Show-AstDiff -Document $Document -Annotate).Count | Should -Be 0
            $Document.ReplaceRange(0, 3, 'ONE', 'Change')
            $Output = @(Show-AstDiff -Document $Document -Annotate -EditIndex @())
            $Output.Count | Should -Be 1
            $Output[0] | Should -BeExactly ''
            { Show-AstDiff -Document $Document -Annotate -EditIndex 1 } | Should -Throw '*out of range*'
        }

        It 'keeps annotation rows uncolored with NoColor=<DisableColor> and NO_COLOR=<EnvironmentValue>' -ForEach @(
            @{ DisableColor = $false; EnvironmentValue = $null; ExpectColor = $true }
            @{ DisableColor = $true; EnvironmentValue = $null; ExpectColor = $false }
            @{ DisableColor = $false; EnvironmentValue = '1'; ExpectColor = $false }
            @{ DisableColor = $false; EnvironmentValue = '0'; ExpectColor = $false }
        ) {
            $OriginalNoColor = $env:NO_COLOR
            try {
                $env:NO_COLOR = $EnvironmentValue
                $Document = New-AstDocument -InputObject 'one'
                $Document.ReplaceRange(0, 3, 'ONE', 'Change')
                $Esc = [char]27
                $Expected = if ($ExpectColor) {
                    @(
                        "${Esc}[1m[0] Change${Esc}[0m",
                        "${Esc}[31m  1 | - one${Esc}[0m",
                        '    |   ^^^',
                        "${Esc}[32m    | + ONE${Esc}[0m",
                        '    |   ^^^'
                    )
                } else {
                    @(
                        '[0] Change',
                        '  1 | - one',
                        '    |   ^^^',
                        '    | + ONE',
                        '    |   ^^^'
                    )
                }
                Show-AstDiff -Document $Document -Annotate -NoColor:$DisableColor |
                    Should -BeExactly ($Expected -join [Environment]::NewLine)
            } finally {
                $env:NO_COLOR = $OriginalNoColor
            }
        }
    }

    It 'does not add color resets to context lines when colors are enabled' {
        $OriginalNoColor = $env:NO_COLOR
        try {
            $env:NO_COLOR = $null
            $Document = New-AstDocument -InputObject "one`ntwo`nthree"
            $Document.ReplaceRange(4, 7, 'TWO', 'Change')
            $Esc = [char]27

            Show-AstDiff -Document $Document -Context 1 |
                Should -BeExactly ((@(
                    "${Esc}[1m[0] Change${Esc}[0m",
                    '  1 |   one',
                    "${Esc}[31m  2 | - two${Esc}[0m",
                    "${Esc}[32m    | + TWO${Esc}[0m",
                    '  3 |   three'
                )) -join [Environment]::NewLine)
        } finally {
            $env:NO_COLOR = $OriginalNoColor
        }
    }

    It 'emits no output when there are no queued edits' {
        $Document = New-AstDocument -InputObject 'one'

        @(Show-AstDiff -Document $Document -NoColor).Count | Should -Be 0
    }

    It 'returns an empty string for an explicitly empty selection' {
        $Document = New-AstDocument -InputObject 'one'
        $Document.ReplaceRange(0, 3, 'ONE', 'Change')

        $Output = @(Show-AstDiff -Document $Document -EditIndex @() -NoColor)

        $Output.Count | Should -Be 1
        $Output[0] | Should -BeExactly ''
    }

    It 'rejects out-of-range edit index <Index>' -ForEach @(
        @{ Index = -1 }
        @{ Index = 1 }
    ) {
        $Document = New-AstDocument -InputObject 'one'
        $Document.ReplaceRange(0, 3, 'ONE', 'Change')

        { Show-AstDiff -Document $Document -EditIndex $Index -NoColor } |
            Should -Throw "Edit index $Index is out of range. Valid range is 0..0."
    }

    It 'sorts and deduplicates selected edit indexes' {
        $Document = New-AstDocument -InputObject "one`ntwo"
        $Document.ReplaceRange(4, 7, 'TWO', 'Second')
        $Document.ReplaceRange(0, 3, 'ONE', 'First')

        $Output = @(Show-AstDiff -Document $Document -EditIndex 1,0,1 -NoColor)

        $Output.Count | Should -Be 1
        $Output[0] | Should -BeExactly ((
            '[0] First', '[1] Second',
            '  1 | - one',
            '  2 | - two',
            '    | + ONE',
            '    | + TWO'
        ) -join [Environment]::NewLine)
    }

    It 'handles <Name> line terminators without displaying a phantom context line' -ForEach @(
        @{ Name = 'LF'; NewLine = "`n" }
        @{ Name = 'CRLF'; NewLine = "`r`n" }
        @{ Name = 'CR'; NewLine = "`r" }
    ) {
        $Source = "one${NewLine}two${NewLine}three${NewLine}"
        $Document = New-AstDocument -InputObject $Source
        $Start = $Source.IndexOf('two')
        $Document.ReplaceRange($Start, $Start + 3, "TWO${NewLine}EXTRA", 'Change')

        Show-AstDiff -Document $Document -NoColor -Context 1 -Label Position |
            Should -BeExactly ((
                '2:1  Change',
                '  1 |   one',
                '  2 | - two',
                '    | + TWO',
                '    | + EXTRA',
                '  3 |   three'
            ) -join [Environment]::NewLine)
    }

    It 'handles an end-of-file insertion in <Name>' -ForEach @(
        @{
            Name = 'empty text'
            Source = ''
            Expected = @('1:1  Append', '    | + MORE')
        }
        @{
            Name = 'an unterminated line'
            Source = 'one'
            Expected = @('1:4  Append', '  1 | - one', '    | + oneMORE')
        }
        @{
            Name = 'terminated text'
            Source = "one`n"
            Expected = @('2:1  Append', '  1 |   one', '    | + MORE')
        }
    ) {
        $Document = New-AstDocument -InputObject $Source
        $Document.Insert($Source.Length, 'MORE', 'Append')

        Show-AstDiff -Document $Document -NoColor -Context 1 -Label Position |
            Should -BeExactly ($Expected -join [Environment]::NewLine)
    }

    It 'preserves color output with NoColor=<DisableColor> and NO_COLOR=<EnvironmentValue>' -ForEach @(
        @{ DisableColor = $false; EnvironmentValue = $null; ExpectColor = $true }
        @{ DisableColor = $true; EnvironmentValue = $null; ExpectColor = $false }
        @{ DisableColor = $false; EnvironmentValue = '1'; ExpectColor = $false }
        @{ DisableColor = $false; EnvironmentValue = '0'; ExpectColor = $false }
    ) {
        $OriginalNoColor = $env:NO_COLOR
        try {
            $env:NO_COLOR = $EnvironmentValue
            $Document = New-AstDocument -InputObject 'one'
            $Document.ReplaceRange(0, 3, 'ONE', 'Change')
            $Esc = [char]27
            $Expected = if ($ExpectColor) {
                @(
                    "${Esc}[1m[0] Change${Esc}[0m",
                    "${Esc}[31m  1 | - one${Esc}[0m",
                    "${Esc}[32m    | + ONE${Esc}[0m"
                )
            } else {
                @('[0] Change', '  1 | - one', '    | + ONE')
            }

            Show-AstDiff -Document $Document -NoColor:$DisableColor |
                Should -BeExactly ($Expected -join [Environment]::NewLine)
        } finally {
            $env:NO_COLOR = $OriginalNoColor
        }
    }

    It 'shows all queued edits in sorted order' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
            param($Node)
            $Node -is [System.Management.Automation.Language.CommandAst] -and
            $Node.GetCommandName() -eq 'Write-Host'
        }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "prepended"', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')
        $Overlay.AppendLine($WriteHostCall, 'Write-Output "appended"', 'Insert additional greeting after Write-Host')

        $Diff = Show-AstDiff -Document $Overlay

        $Diff | Should -Match '\[0\] Insert greeting before Write-Host'
        $Diff | Should -Match '\[1\] Replace Write-Host with Write-Output'
        $Diff | Should -Match '\[2\] Insert additional greeting after Write-Host'
        $Diff | Should -Match 'prepended'
        $Diff | Should -Match 'appended'
    }

    It 'shows only selected edit indexes' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
            param($Node)
            $Node -is [System.Management.Automation.Language.CommandAst] -and
            $Node.GetCommandName() -eq 'Write-Host'
        }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "prepended"', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')
        $Overlay.AppendLine($WriteHostCall, 'Write-Output "appended"', 'Insert additional greeting after Write-Host')

        $Diff = Show-AstDiff -Document $Overlay -EditIndex 1

        $Diff | Should -Match '\[1\] Replace Write-Host with Write-Output'
        $Diff | Should -Not -Match '\[0\] Insert greeting before Write-Host'
        $Diff | Should -Not -Match '\[2\] Insert additional greeting after Write-Host'
    }

    It 'allows selecting the first edit index' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
            param($Node)
            $Node -is [System.Management.Automation.Language.CommandAst] -and
            $Node.GetCommandName() -eq 'Write-Host'
        }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "prepended"', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')

        $Diff = Show-AstDiff -Document $Overlay -EditIndex 0

        $Diff | Should -Match '\[0\] Insert greeting before Write-Host'
        $Diff | Should -Not -Match '\[1\] Replace Write-Host with Write-Output'
    }

    It 'groups edits on the same line into one hunk of complete lines' {
        $Source = "`$a = 1`nif (-not (`$Value -is [int])) {`n    'x'`n}`n"
        $Document = New-AstDocument -InputObject $Source
        $NotStart = $Source.IndexOf('-not ')
        $IsStart = $Source.IndexOf('-is ')

        $null = Add-AstTextEdit -Document $Document -TextEdit @(
            New-AstTextEdit -Document $Document -StartOffset $NotStart -EndOffset ($NotStart + 5) `
                -ReplacementText '' -Reason 'Remove unary negation.'

            New-AstTextEdit -Document $Document -StartOffset $IsStart -EndOffset ($IsStart + 3) `
                -ReplacementText '-isnot' -Reason 'Use -isnot.'
        )

        $Diff = Show-AstDiff -Document $Document -NoColor

        $Diff | Should -BeExactly ((
            '[0] Remove unary negation.',
            '[1] Use -isnot.',
            '  2 | - if (-not ($Value -is [int])) {',
            '    | + if (($Value -isnot [int])) {'
        ) -join [Environment]::NewLine)
    }

    It 'prints identical reasons once with all edit indexes in a hunk' {
        $Source = '-not ($Value -is [int])'
        $Document = New-AstDocument -InputObject $Source
        $NegationStart = $Source.IndexOf('-not')
        $OperatorStart = $Source.IndexOf('-is')
        $Reason = "Replace '-not (<expr> -is <type>)' with '<expr> -isnot <type>'."
        $null = Add-AstTextEdit -Document $Document -TextEdit @(
            New-AstTextEdit `
                -Document $Document `
                -StartOffset $NegationStart `
                -EndOffset ($NegationStart + 4) `
                -ReplacementText '' `
                -Reason $Reason

            New-AstTextEdit `
                -Document $Document `
                -StartOffset $OperatorStart `
                -EndOffset ($OperatorStart + 3) `
                -ReplacementText '-isnot' `
                -Reason $Reason
        )

        $Diff = Show-AstDiff -Document $Document -NoColor

        $Diff | Should -BeExactly ((
            "[0, 1] $Reason",
            '  1 | - -not ($Value -is [int])',
            '    | +  ($Value -isnot [int])'
        ) -join [Environment]::NewLine)
    }

    It 'labels each reason with the line:column of its first edit when Label is Position' {
        $Source = "`$a = 1`n  -not (`$Value -is [int])`n"
        $Document = New-AstDocument -InputObject $Source
        $NegationStart = $Source.IndexOf('-not')
        $OperatorStart = $Source.IndexOf('-is ')
        $Reason = "Replace '-not (<expr> -is <type>)' with '<expr> -isnot <type>'."
        $null = Add-AstTextEdit -Document $Document -TextEdit @(
            New-AstTextEdit `
                -Document $Document `
                -StartOffset 0 `
                -EndOffset 2 `
                -ReplacementText '$b' `
                -Reason 'Rename'

            New-AstTextEdit `
                -Document $Document `
                -StartOffset $OperatorStart `
                -EndOffset ($OperatorStart + 3) `
                -ReplacementText '-isnot' `
                -Reason $Reason

            New-AstTextEdit `
                -Document $Document `
                -StartOffset $NegationStart `
                -EndOffset ($NegationStart + 4) `
                -ReplacementText '' `
                -Reason $Reason
        )

        $Diff = Show-AstDiff -Document $Document -NoColor -Label Position

        $Diff | Should -BeExactly ((
            '1:1  Rename',
            "2:3  $Reason",
            '  1 | - $a = 1',
            '  2 | -   -not ($Value -is [int])',
            '    | + $b = 1',
            '    | +    ($Value -isnot [int])'
        ) -join [Environment]::NewLine)
    }

    It 'shows <Context> unchanged lines around hunks and merges overlapping context' -ForEach @(
        @{
            Context = 0
            Expected = @(
                '[0] Change two',
                '  2 | - two',
                '    | + TWO',
                '',
                '[1] Change five',
                '  5 | - five',
                '    | + FIVE'
            )
        }
        @{
            Context = 1
            Expected = @(
                '[0] Change two', '[1] Change five',
                '  1 |   one',
                '  2 | - two',
                '    | + TWO',
                '  3 |   three',
                '  4 |   four',
                '  5 | - five',
                '    | + FIVE'
            )
        }
    ) {
        $Source = "one`ntwo`nthree`nfour`nfive`n"
        $Document = New-AstDocument -InputObject $Source
        $null = Add-AstTextEdit -Document $Document -TextEdit @(
            New-AstTextEdit -Document $Document -StartOffset 4 -EndOffset 7 -ReplacementText 'TWO' -Reason 'Change two'
            New-AstTextEdit -Document $Document -StartOffset 19 -EndOffset 23 -ReplacementText 'FIVE' -Reason 'Change five'
        )

        Show-AstDiff -Document $Document -NoColor -Context $Context |
            Should -BeExactly ($Expected -join [Environment]::NewLine)
    }

    It 'shows joined lines and whole-line removals without placeholder text' {
        $Source = "one`ntwo`nthree`nfour`n"
        $Document = New-AstDocument -InputObject $Source
        $null = Add-AstTextEdit -Document $Document -TextEdit @(
            New-AstTextEdit -Document $Document -StartOffset 2 -EndOffset 4 -ReplacementText 'E' -Reason 'Join'
            New-AstTextEdit -Document $Document -StartOffset 8 -EndOffset 14 -ReplacementText '' -Reason 'Remove three'
        )

        $Diff = Show-AstDiff -Document $Document -NoColor

        $Diff | Should -BeExactly ((
            '[0] Join', '[1] Remove three',
            '  1 | - one',
            '  2 | - two',
            '  3 | - three',
            '    | + onEtwo'
        ) -join [Environment]::NewLine)
    }
}
