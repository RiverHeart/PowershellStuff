Describe 'Complete-WPFColor' -Tag 'Complete-WPFColor' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    It 'returns a quoted hash-prefixed completion for six-digit hex input without a hash' {
        $result = @(Complete-WPFColor -WordToComplete 'FFFFFF')

        $result.Count | Should -Be 1
        $result[0].CompletionText | Should -Be "'#FFFFFF'"
        $result[0].ListItemText | Should -Be '#FFFFFF'
        $result[0].ToolTip | Should -Be 'Hex color'
    }

    It 'returns a quoted hash-prefixed completion for partial hex input that already starts with a hash' {
        $result = @(Complete-WPFColor -WordToComplete '#FF')

        $result.Count | Should -Be 1
        $result[0].CompletionText | Should -Be "'#FF'"
        $result[0].ListItemText | Should -Be '#FF'
    }

    It 'returns a quoted hash-prefixed completion first for unprefixed partial hex input' {
        $result = @(Complete-WPFColor -WordToComplete 'ff')

        $result.Count | Should -BeGreaterThan 1
        $result[0].CompletionText | Should -Be "'#ff'"
        $result[0].ListItemText | Should -Be '#ff'
        $result[0].ToolTip | Should -Be 'Hex color'
        $result[1].ListItemText | Should -Be 'LemonChiffon'
    }

    It 'preserves surrounding quotes when completing hex input' {
        $result = @(Complete-WPFColor -WordToComplete "'ABCDEF")

        $result.Count | Should -Be 1
        $result[0].CompletionText | Should -Be "'#ABCDEF'"
        $result[0].ListItemText | Should -Be '#ABCDEF'
    }

    It 'continues to return named colors for non-hex input' {
        $result = @(Complete-WPFColor -WordToComplete 'Blue')

        $result.Count | Should -BeGreaterThan 0
        $result[0].CompletionText | Should -Be 'Blue'
        $result[0].ListItemText | Should -Be 'Blue'
        $result[0].ToolTip | Should -Be 'Color'
    }
}
