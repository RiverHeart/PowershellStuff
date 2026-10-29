using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Show-AstDiff' {
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
            '  1 - one', '  2 - two', '    + ONE', '    + TWO'
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
                '2:1  Change', '  1   one', '  2 - two',
                '    + TWO', '    + EXTRA', '  3   three'
            ) -join [Environment]::NewLine)
    }

    It 'handles an end-of-file insertion in <Name>' -ForEach @(
        @{
            Name = 'empty text'
            Source = ''
            Expected = @('1:1  Append', '    + MORE')
        }
        @{
            Name = 'an unterminated line'
            Source = 'one'
            Expected = @('1:4  Append', '  1 - one', '    + oneMORE')
        }
        @{
            Name = 'terminated text'
            Source = "one`n"
            Expected = @('2:1  Append', '  1   one', '    + MORE')
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
                @("${Esc}[1m[0] Change${Esc}[0m", "${Esc}[31m  1 - one${Esc}[0m", "${Esc}[32m    + ONE${Esc}[0m")
            } else {
                @('[0] Change', '  1 - one', '    + ONE')
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
            '  2 - if (-not ($Value -is [int])) {',
            '    + if (($Value -isnot [int])) {'
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
            '  1 - -not ($Value -is [int])',
            '    +  ($Value -isnot [int])'
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
            '  1 - $a = 1',
            '  2 -   -not ($Value -is [int])',
            '    + $b = 1',
            '    +    ($Value -isnot [int])'
        ) -join [Environment]::NewLine)
    }

    It 'shows <Context> unchanged lines around hunks and merges overlapping context' -ForEach @(
        @{
            Context = 0
            Expected = @(
                '[0] Change two', '  2 - two', '    + TWO', '',
                '[1] Change five', '  5 - five', '    + FIVE'
            )
        }
        @{
            Context = 1
            Expected = @(
                '[0] Change two', '[1] Change five',
                '  1   one', '  2 - two', '    + TWO', '  3   three', '  4   four', '  5 - five', '    + FIVE'
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
            '  1 - one', '  2 - two', '  3 - three', '    + onEtwo'
        ) -join [Environment]::NewLine)
    }
}
