Describe 'DataGridTextColumn' -Tag 'DataGridTextColumn' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -DataGridTextColumn 'CPU' 'CpuPercent' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create a DataGridTextColumn with header and binding path' {
        $Result = DataGridTextColumn 'Name' 'ProcessName' {}

        $Result | Should -BeOfType [System.Windows.Controls.DataGridTextColumn]
        $Result.Header | Should -Be 'Name'
        $Result.Binding.Path.Path | Should -Be 'ProcessName'
    }

    It 'Should auto-attach DataGridTextColumn when declared inside DataGrid' {
        $id = [guid]::NewGuid().ToString('N')

        $grid = DataGrid "Grid_$id" {
            DataGridTextColumn 'Name' 'ProcessName' {}
            DataGridTextColumn 'Id' 'Id' {}
        }

        $grid.Columns.Count | Should -Be 2
        $grid.Columns[0].Header | Should -Be 'Name'
        $grid.Columns[1].Header | Should -Be 'Id'
    }

    It 'Should apply HeaderStyle and ElementStyle via UseStyle on DataGridTextColumn' {
        $id = [guid]::NewGuid().ToString('N')
        $headerStyleName = "HeaderStyle_$id"
        $cellStyleName = "CellStyle_$id"

        Style $headerStyleName DataGridColumnHeader {
            Setter HorizontalContentAlignment ([System.Windows.HorizontalAlignment]::Right)
        }

        Style $cellStyleName TextBlock {
            Setter HorizontalAlignment ([System.Windows.HorizontalAlignment]::Right)
        }

        $column = DataGridTextColumn 'CPU' 'CpuPercent' {
            UseStyle $headerStyleName $this -TargetType HeaderStyle
            UseStyle $cellStyleName $this -TargetType ElementStyle
        }

        $column.HeaderStyle | Should -Not -BeNullOrEmpty
        $column.ElementStyle | Should -Not -BeNullOrEmpty
        $column.HeaderStyle.TargetType | Should -Be ([System.Windows.Controls.Primitives.DataGridColumnHeader])
        $column.ElementStyle.TargetType | Should -Be ([System.Windows.Controls.TextBlock])
    }
}
