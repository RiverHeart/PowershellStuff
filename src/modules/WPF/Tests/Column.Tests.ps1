Describe 'Column' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should be able to add a control to itself' {
        $Children = Column {
            Label 'Foobar' {}
        }
        $Children.Count | Should -Be -ExpectedValue 1
    }
}
