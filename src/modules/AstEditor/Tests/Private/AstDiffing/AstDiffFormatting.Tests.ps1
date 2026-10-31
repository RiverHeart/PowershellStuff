BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Add-AstDiffLine splitting' {
    It 'preserves display lines for <Name> without emitting output' -ForEach @(
        @{ Name = 'empty text'; Value = ''; Expected = @() }
        @{ Name = 'one line'; Value = 'one'; Expected = @('one') }
        @{ Name = 'a blank line'; Value = "`n"; Expected = @('') }
        @{ Name = 'LF'; Value = "one`ntwo`n"; Expected = @('one', 'two') }
        @{ Name = 'CRLF'; Value = "one`r`ntwo`r`n"; Expected = @('one', 'two') }
        @{ Name = 'CR'; Value = "one`rtwo`r"; Expected = @('one', 'two') }
        @{ Name = 'trailing blank lines'; Value = "one`n`n"; Expected = @('one', '') }
        @{ Name = 'mixed terminators'; Value = "one`r`ntwo`nthree`rfour"; Expected = @('one', 'two', 'three', 'four') }
    ) {
        InModuleScope AstEditor -Parameters @{ Value = $Value; Expected = $Expected } {
            param ($Value, $Expected)

            $Builder = [System.Text.StringBuilder]::new()
            $DirectBuilder = [System.Text.StringBuilder]::new()
            $Output = @(
                $Value | Add-AstDiffLine -Builder $Builder -GutterWidth 1 -Marker '+'
                Add-AstDiffLine -Text $Value -Builder $DirectBuilder -GutterWidth 1 -Marker '+'
            )
            $ExpectedText = ''
            foreach ($Line in $Expected) {
                $ExpectedText += "    | + $Line" + [Environment]::NewLine
            }

            $Output.Count | Should -Be 0
            $Builder.ToString() | Should -BeExactly $ExpectedText
            $DirectBuilder.ToString() | Should -BeExactly $ExpectedText
        }
    }
}

Describe 'Add-AstDiffLine' {
    It 'continues numbering across pipeline text chunks, including empty input' {
        InModuleScope AstEditor {
            $Expected = (@(
                '  3 | - one',
                '  4 | - ',
                '  5 | - two',
                '  6 | - three'
            ) -join [Environment]::NewLine) + [Environment]::NewLine
            $Texts = @("one`n`n", '', "two`r`nthree`r`n")
            $PipelineBuilder = [System.Text.StringBuilder]::new()

            $Output = @(
                $Texts | Add-AstDiffLine -Builder $PipelineBuilder -GutterWidth 1 -LineNumber 3 -Marker '-'
            )

            $Output.Count | Should -Be 0
            $PipelineBuilder.ToString() | Should -BeExactly $Expected
        }
    }

    It 'appends numbered, unnumbered, and blank lines without emitting output' {
        InModuleScope AstEditor {
            $Builder = [System.Text.StringBuilder]::new()
            $Esc = [char]27
            $OriginalNoColor = $env:NO_COLOR

            try {
                $env:NO_COLOR = $null
                $Output = @(
                    "old`nolder" | Add-AstDiffLine -Builder $Builder -GutterWidth 2 -LineNumber 3 `
                        -Marker '-' -Color Red
                    "new`nnewer" | Add-AstDiffLine -Builder $Builder -GutterWidth 2 -Marker '+'
                    "`n" | Add-AstDiffLine -Builder $Builder -GutterWidth 2 -LineNumber 10 -Marker ' '
                )
            } finally {
                $env:NO_COLOR = $OriginalNoColor
            }

            $Output.Count | Should -Be 0
            $Builder.ToString() | Should -BeExactly ((@(
                "${Esc}[31m   3 | - old${Esc}[0m",
                "${Esc}[31m   4 | - older${Esc}[0m",
                '     | + new',
                '     | + newer',
                '  10 |   '
            ) -join [Environment]::NewLine) + [Environment]::NewLine)
        }
    }
}

Describe 'Add-AstDiffContext' {
    It 'appends only the inclusive source range and ignores reversed ranges' {
        InModuleScope AstEditor {
            $Builder = [System.Text.StringBuilder]::new()
            $Text = "one`r`n`r`nthree"
            $LineRecords = Get-AstTextLine -Text $Text

            $Output = @(
                Add-AstDiffContext -Builder $Builder -Text $Text -LineRecords $LineRecords `
                    -From 1 -To 2 -GutterWidth 2
                Add-AstDiffContext -Builder $Builder -Text $Text -LineRecords $LineRecords `
                    -From 1 -To 0 -GutterWidth 2
            )

            $Output.Count | Should -Be 0
            $Builder.ToString() | Should -BeExactly (
                '   2 |   ' + [Environment]::NewLine + '   3 |   three' + [Environment]::NewLine
            )
        }
    }
}
