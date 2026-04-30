Describe 'Row' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should return a row specification with columns' {
        $Id = [guid]::NewGuid().ToString('N')
        $Row = Row {
            Column {
                Label "Foobar_$Id" {}
            }
            Column {
                Label "Barfu_$Id" {}
                Label "Bazbar_$Id" {}
            }
        }

        $Row.PSTypeNames | Should -Contain 'WPF.Grid.RowSpec'
        $Row.Columns.Count | Should -Be -ExpectedValue 2
        $Row.Columns[0].Children.Count | Should -Be -ExpectedValue 1
        $Row.Columns[1].Children.Count | Should -Be -ExpectedValue 2
    }

    It 'Should normalize explicit height aliases' {
        $Id = [guid]::NewGuid().ToString('N')
        $Row = Row 'Expand*2' {
            Column {
                Label "Foobar_$Id" {}
            }
        }

        $Row.Height.IsStar | Should -BeTrue
        $Row.Height.Value | Should -Be -ExpectedValue 2
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')

        $Row = -Row {
            Column {
                Label "Foobar_$Id" {}
            }
        }

        $Row | Should -BeNullOrEmpty
    }
}
