Describe 'Grid' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should be able to add rows' {
        $Grid = Grid 'Grid' {
            Row {
                Column {
                    Label 'Foo' {}
                    Label 'Fubar' {}
                }
                Column {
                    Label 'Bar' {}
                    Label 'Barfu' {}
                    Label 'Barbaz' {}
                }
            }
            Row {
                Column {
                    Label 'Bazfu' {}
                    Label 'Bazbar' {}
                    Label 'Bazbaz' {}
                    Label 'Bazbarfu' {}
                }
            }
        }

        $Grid.Children | Should -HaveCount 9

        # Check R0/C0
        $Grid.Children | Where-Object {
            [System.Windows.Controls.Grid]::GetRow($_) -eq  0 -and
            [System.Windows.Controls.Grid]::GetColumn($_) -eq  0
        } | Should -HaveCount 2

        # Check R0/C1
        $Grid.Children | Where-Object {
            [System.Windows.Controls.Grid]::GetRow($_) -eq  0 -and
            [System.Windows.Controls.Grid]::GetColumn($_) -eq  1
        } | Should -HaveCount 3

        # Check R1/C0
        $Grid.Children | Where-Object {
            [System.Windows.Controls.Grid]::GetRow($_) -eq  1 -and
            [System.Windows.Controls.Grid]::GetColumn($_) -eq  0
        } | Should -HaveCount 4
    }
}
