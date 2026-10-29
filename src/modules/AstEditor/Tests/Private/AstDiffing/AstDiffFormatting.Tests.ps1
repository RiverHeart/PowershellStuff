BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Split-AstDiffDisplayLine' {
    It 'preserves display lines and array shape for <Name>' -ForEach @(
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

            $Output = @(Split-AstDiffDisplayLine -Value $Value)

            $Output.Count | Should -Be 1
            Should -ActualValue $Output[0] -BeOfType ([array])
            $Output[0].Count | Should -Be $Expected.Count
            for ($Index = 0; $Index -lt $Expected.Count; $Index++) {
                $Output[0][$Index] | Should -BeExactly $Expected[$Index]
            }
        }
    }
}

Describe 'Add-AstDiffLine' {
    It 'appends numbered, unnumbered, and blank lines without emitting output' {
        InModuleScope AstEditor {
            $Builder = [System.Text.StringBuilder]::new()
            $Esc = [char]27

            $Output = @(
                Add-AstDiffLine -Builder $Builder -NumberWidth 2 -LineNumber 3 `
                    -Marker '-' -Content 'old' -Color "${Esc}[31m" -Reset "${Esc}[0m"
                Add-AstDiffLine -Builder $Builder -NumberWidth 2 -Marker '+' -Content 'new'
                Add-AstDiffLine -Builder $Builder -NumberWidth 2 -LineNumber 10 `
                    -Marker ' ' -Content '' -Reset "${Esc}[0m"
            )

            $Output.Count | Should -Be 0
            $Builder.ToString() | Should -BeExactly ((@(
                "${Esc}[31m   3 - old${Esc}[0m", '     + new', '  10   '
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
                    -From 1 -To 2 -NumberWidth 2
                Add-AstDiffContext -Builder $Builder -Text $Text -LineRecords $LineRecords `
                    -From 1 -To 0 -NumberWidth 2
            )

            $Output.Count | Should -Be 0
            $Builder.ToString() | Should -BeExactly (
                '   2   ' + [Environment]::NewLine + '   3   three' + [Environment]::NewLine
            )
        }
    }
}
