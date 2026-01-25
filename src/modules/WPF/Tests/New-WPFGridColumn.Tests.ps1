Describe 'New-WPFGridColumn' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should exist' {
        $Command = Get-Command 'New-WPFGridColumn'
        $Command | Should -HaveParameter 'NameOrWidth' -Type [string]
        #$Command | Should -HaveParameter 'Width' -Type [GridLength]
        $Command | Should -HaveParameter 'ScriptBlock' -Type [scriptblock]
        $Command.OutputType.Name | Should -Contain 'System.Windows.Controls.ColumnDefinition'
    }

    It 'Should be resolve all parameter sets' {
        # Implicit
        { Cell 'Test1' {} } | Should -BindParams @{ NameOrWidth = 'Test1'; Scriptblock = $null }

        # # Explicit
        { Cell 'Test2' 'Fit' {} } | Should -BindParams @{
            NameOrWidth = 'Test1'
            Width = 'Fit'
            Scriptblock = $null
        }

        # # Inferred Width
        { Cell 'Expand' {} } | Should -BindParams @{
            NameOrWidth = '__Nameless__'
            Width = '*'
        }

        # Barebones
        { Cell {} } | Should -BindParams @{
            NameOrWidth = '__Nameless__'
            Width = 'Auto'
            Scriptblock = $null
        }
    }

    It 'Should be able to add a control to itself' {
        $Column = Cell {
            Label 'Foobar' {}
        }
        $Column.Children | Should -HaveCount 1
        $Column.Children[0] | Should -BeOfType [System.Windows.Controls.Label]
    }
}
