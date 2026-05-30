Describe 'Grid' -Tag 'Grid' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should expose this as the current grid in scriptblock' {
        $Id = [guid]::NewGuid().ToString('N')
        $Grid = Grid "Grid_$Id" {
            $this.Margin = 8

            Row {
                Column {
                    Label "Foo_$Id" {}
                }
            }
        }

        $Grid.Margin.Left | Should -Be -ExpectedValue 8
        $Grid.Margin.Top | Should -Be -ExpectedValue 8
        $Grid.Margin.Right | Should -Be -ExpectedValue 8
        $Grid.Margin.Bottom | Should -Be -ExpectedValue 8
    }

    It 'Should be able to add rows' {
        $Id = [guid]::NewGuid().ToString('N')
        $Grid = Grid "Grid_$Id" {
            Row {
                Column {
                    Label "Foo_$Id" {}
                    Label "Fubar_$Id" {}
                }
                Column {
                    Label "Bar_$Id" {}
                    Label "Barfu_$Id" {}
                    Label "Barbaz_$Id" {}
                }
            }
            Row {
                Column {
                    Label "Bazfu_$Id" {}
                    Label "Bazbar_$Id" {}
                    Label "Bazbaz_$Id" {}
                    Label "Bazbarfu_$Id" {}
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

        $Grid.RowDefinitions.Count | Should -Be -ExpectedValue 2
        $Grid.ColumnDefinitions.Count | Should -Be -ExpectedValue 2
    }

    It 'Should not fail resolving row and column definition types' {
        $Id = [guid]::NewGuid().ToString('N')

        {
            $Grid = Grid "GridTypeResolution_$Id" {
                Row {
                    Column {
                        Label "TypeLabelA_$Id" {}
                    }
                    Column {
                        Label "TypeLabelB_$Id" {}
                    }
                }
                Row {
                    Column {
                        Label "TypeLabelC_$Id" {}
                    }
                }
            }

            $Grid.RowDefinitions[0] | Should -BeOfType [System.Windows.Controls.RowDefinition]
            $Grid.ColumnDefinitions[0] | Should -BeOfType [System.Windows.Controls.ColumnDefinition]
            $Grid.RowDefinitions.Count | Should -Be -ExpectedValue 2
            $Grid.ColumnDefinitions.Count | Should -Be -ExpectedValue 2
        } | Should -Not -Throw
    }

    It 'Should infer max columns without expanding on shorter rows' {
        $Id = [guid]::NewGuid().ToString('N')
        $Grid = Grid "Grid_$Id" {
            Row {
                Column {
                    Label "A_$Id" {}
                }
                Column {
                    Label "B_$Id" {}
                }
                Column {
                    Label "C_$Id" {}
                }
                Column {
                    Label "D_$Id" {}
                }
            }
            Row {
                Column {
                    Label "E_$Id" {}
                }
                Column {
                    Label "F_$Id" {}
                }
                Column {
                    Label "G_$Id" {}
                }
            }
        }

        $Grid.RowDefinitions.Count | Should -Be -ExpectedValue 2
        $Grid.ColumnDefinitions.Count | Should -Be -ExpectedValue 4
    }

    It 'Should place Border children in their declared grid columns' {
        $Id = [guid]::NewGuid().ToString('N')
        $Grid = Grid "GridBorder_$Id" {
            Row {
                Column {
                    Border "LeftBorder_$Id" {
                        Label "LeftLabel_$Id" {}
                    }
                }
                Column {
                    Border "RightBorder_$Id" {
                        Label "RightLabel_$Id" {}
                    }
                }
            }
        }

        $LeftBorder = Reference "LeftBorder_$Id"
        $RightBorder = Reference "RightBorder_$Id"

        [System.Windows.Controls.Grid]::GetRow($LeftBorder) | Should -Be 0
        [System.Windows.Controls.Grid]::GetColumn($LeftBorder) | Should -Be 0
        [System.Windows.Controls.Grid]::GetRow($RightBorder) | Should -Be 0
        [System.Windows.Controls.Grid]::GetColumn($RightBorder) | Should -Be 1
    }

    It 'Should place TextBox children in their declared grid columns' {
        $Id = [guid]::NewGuid().ToString('N')
        $Grid = Grid "GridTextBox_$Id" {
            Row {
                Column {
                    TextBox "LeftTextBox_$Id" {
                        $this.Text = 'Left'
                    }
                }
                Column {
                    TextBox "RightTextBox_$Id" {
                        $this.Text = 'Right'
                    }
                }
            }
        }

        $LeftTextBox = Reference "LeftTextBox_$Id"
        $RightTextBox = Reference "RightTextBox_$Id"

        [System.Windows.Controls.Grid]::GetRow($LeftTextBox) | Should -Be 0
        [System.Windows.Controls.Grid]::GetColumn($LeftTextBox) | Should -Be 0
        [System.Windows.Controls.Grid]::GetRow($RightTextBox) | Should -Be 0
        [System.Windows.Controls.Grid]::GetColumn($RightTextBox) | Should -Be 1
    }

    It 'Should honor explicit row and column sizes from first declaration' {
        $Id = [guid]::NewGuid().ToString('N')
        $Grid = Grid "Grid_$Id" {
            Row 'Expand*2' {
                Column 'Expand*3' {
                    Label "A_$Id" {}
                }
                Column {
                    Label "B_$Id" {}
                }
            }
            Row {
                Column {
                    Label "C_$Id" {}
                }
            }
        }

        $Grid.RowDefinitions[0].Height.IsStar | Should -BeTrue
        $Grid.RowDefinitions[0].Height.Value | Should -Be -ExpectedValue 2
        $Grid.ColumnDefinitions[0].Width.IsStar | Should -BeTrue
        $Grid.ColumnDefinitions[0].Width.Value | Should -Be -ExpectedValue 3
    }

    It 'Should auto-attach to injected parent context and not return nested grids' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()
        $psVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Grid "Body_$Id" {
                Row {
                    Column {
                        Label "NestedLabel_$Id" {}
                    }
                }
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be -ExpectedValue 0
        $Parent.Content | Should -Not -BeNullOrEmpty
        $Parent.Content.Name | Should -Be -ExpectedValue "Body_$Id"
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -Grid "Grid_$Id" {
                Row {
                    Column {
                        Label "Label_$Id" {}
                    }
                }
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }
}

Describe 'New-WPFGrid' -Tag 'New-WPFGrid' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should initialize requested rows and columns' {
        $Id = [guid]::NewGuid().ToString('N')
        $Grid = New-WPFGrid -Name "Grid_$Id" -Rows 2 -Columns 3

        $Grid.RowDefinitions.Count | Should -Be -ExpectedValue 2
        $Grid.ColumnDefinitions.Count | Should -Be -ExpectedValue 3
    }
}
