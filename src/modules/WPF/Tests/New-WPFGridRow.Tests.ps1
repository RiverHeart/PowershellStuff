Describe 'New-WPFGridColumn' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force

        # FIXME: No idea why this stopped working...
        #. "$PSScriptRoot/CustomAssertions/Should-BindParams.ps1"
    }

    It 'Should exist' {
        $Command = Get-Command 'New-WPFGridRow'
        $Command | Should -HaveParameter 'NameOrHeight' -Type [string]
        $Command | Should -HaveParameter 'Height' -Type [string]
        $Command | Should -HaveParameter 'ScriptBlock' -Type [scriptblock]
        $Command.OutputType.Name | Should -Contain 'System.Windows.Controls.RowDefinition'
    }

    # It 'Should be resolve all parameter sets' {
    #     # Bare
    #     { Row {} } | Should -BindParams @{
    #         NameOrHeight = '__Nameless__'
    #         Height = 'Auto'
    #         Scriptblock = $null
    #     }

    #     # Single Init (Height)
    #     { Row 'Expand' {} } | Should -BindParams @{ NameOrHeight = '__Nameless__'; Height = '*'; Scriptblock = $Null}

    #     # Single Init (Name)
    #     { Row 'Test1' {} } | Should -BindParams @{ NameOrHeight = 'Test1'; Scriptblock = $null }

    #     # Double Init
    #     { Row 'Test2' 'Fit' {} } | Should -BindParams @{
    #         NameOrHeight = 'Test1'
    #         Height = 'Fit'
    #         Scriptblock = $null
    #     }
    # }

    It 'Should be able to add a column to itself' {
        $Row = Row {
            Cell {
                Label 'Foobar' {}
            }
        }
        $Row.Children | Should -HaveCount 1
        $Row.Children[0] | Should -BeOfType [System.Windows.Controls.ColumnDefinition]

        $Row.Children[0].Children | Should -HaveCount 1
        $Row.Children[0].Children[0] | Should -BeOfType [System.Windows.Controls.Label]
    }
}
