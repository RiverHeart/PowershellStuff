Describe 'Column' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should return a column specification with children' {
        $Id = [guid]::NewGuid().ToString('N')
        $Column = Column {
            Label "Foobar_$Id" {}
        }

        $Column.PSTypeNames | Should -Contain 'WPF.Grid.ColumnSpec'
        $Column.Children.Count | Should -Be -ExpectedValue 1
    }

    It 'Should normalize explicit width aliases' {
        $Id = [guid]::NewGuid().ToString('N')
        $Column = Column 'Expand*3' {
            Label "Foobar_$Id" {}
        }

        $Column.Width.IsStar | Should -BeTrue
        $Column.Width.Value | Should -Be -ExpectedValue 3
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Column = -Column {
            Label "Foobar_$Id" {}
        }

        $Column | Should -BeNullOrEmpty
    }
}
