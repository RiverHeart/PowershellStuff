Describe 'New-WPFGrid' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should exist' {
        $Command = Get-Command 'New-WPFGrid'
        $Command | Should -Not -BeNullOrEmpty
        $Command | Should -HaveParameter 'Name'
        $Command | Should -HaveParameter 'ScriptBlock'
        $Command.OutputType.Name | Should -Contain 'System.Windows.Controls.Grid'
    }

    It 'Should be able to add rows' {
        Grid 'Grid' {
            Row {
                Cell {
                    Label 'Foo' {}
                }
                Cell {
                    Label 'Bar' {}
                }
            }
            Row {
                Cell {
                    Label 'Baz' {}
                }
            }
        }
    }

    # It 'Should be able to add a row and column' {
    #     Grid 'Grid' {
    #         Row {
    #             Cell {}
    #         }
    #     }
    # }

    # It 'Should be able to add rows and columns with children' {
    #     Grid 'Grid' {
    #         Row {
    #             Cell {
    #                 Label 'Foobar'
    #             }
    #         }
    #     }
    # }
}
