Describe 'Row' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should be able to add a control to itself' {
        $Children = Row {
            Column {
                Label 'Foobar' {}
            }
            Column {
                Label 'Barfu' {}
                Label 'Bazbar' {}
            }
        }
        $Children.Count | Should -Be -ExpectedValue 2
        $Children[0].Count | Should -Be -ExpectedValue 1
        $Children[1].Count | Should -Be -ExpectedValue 2
    }
}
