BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AstLineIndexFromOffset' {
    It 'maps every offset in <Name> to its containing line record' -ForEach @(
        @{ Name = 'empty text'; Text = ''; ExpectedIndexes = @(0) }
        @{ Name = 'a single line'; Text = 'abc'; ExpectedIndexes = @(0, 0, 0, 0) }
        @{ Name = 'LF text'; Text = "a`nb"; ExpectedIndexes = @(0, 0, 1, 1) }
        @{ Name = 'CRLF text'; Text = "a`r`nb"; ExpectedIndexes = @(0, 0, 0, 1, 1) }
        @{ Name = 'CR text'; Text = "a`rb"; ExpectedIndexes = @(0, 0, 1, 1) }
        @{ Name = 'a trailing terminator'; Text = "a`r`n"; ExpectedIndexes = @(0, 0, 0, 1) }
        @{ Name = 'consecutive terminators'; Text = "`n`n"; ExpectedIndexes = @(0, 1, 2) }
        @{
            Name = 'mixed terminators'
            Text = "a`r`nb`nc`rd"
            ExpectedIndexes = @(0, 0, 0, 1, 1, 2, 2, 3, 3)
        }
    ) {
        InModuleScope AstEditor -Parameters @{ Text = $Text; ExpectedIndexes = $ExpectedIndexes } {
            param ($Text, $ExpectedIndexes)

            $LineRecords = Get-AstTextLine -Text $Text

            for ($Offset = 0; $Offset -le $Text.Length; $Offset++) {
                $Output = @(Get-AstLineIndexFromOffset -LineRecords $LineRecords -Offset $Offset)

                $Output.Count | Should -Be 1
                $Output[0] | Should -BeOfType ([int])
                $Output[0] | Should -Be $ExpectedIndexes[$Offset]
            }
        }
    }
}
