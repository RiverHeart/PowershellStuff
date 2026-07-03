Describe 'ListView' -Tag 'ListView' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -ListView 'MyListView' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create a ListView with the given name' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = ListView "ListView_$Id" {}

        $Result | Should -BeOfType [System.Windows.Controls.ListView]
        $Result.Name | Should -Be "ListView_$Id"
    }

    It 'Should attach a GridView when declared inside ListView' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = ListView "ListView_$Id" {
            GridView {
                GridViewColumn {
                    $this.Header = 'Name'
                    $this.DisplayMemberBinding = [System.Windows.Data.Binding] 'ProcessName'
                }
            }
        }

        $Result.View | Should -BeOfType [System.Windows.Controls.GridView]
        $Result.View.Columns.Count | Should -Be 1
        $Result.View.Columns[0].Header | Should -Be 'Name'
        $Result.View.Columns[0].DisplayMemberBinding.Path.Path | Should -Be 'ProcessName'
    }

    It 'Should not re-add GridViewColumn when ListView is nested inside Grid' {
        $Id = [guid]::NewGuid().ToString('N')

        {
            $ErrorActionPreference = 'Stop'

            $null = Window "Window_$Id" {
                Grid "Grid_$Id" {
                    Row {
                        Column {
                            ListView "ListView_$Id" {
                                GridView {
                                    GridViewColumn {
                                        $this.Header = 'Amount'
                                        $this.DisplayMemberBinding = Binding 'Amount'
                                    }

                                    GridViewColumn {
                                        $this.Header = 'Interest'
                                        $this.DisplayMemberBinding = Binding 'Interest'
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } | Should -Not -Throw

        $ListView = Reference "ListView_$Id"
        $ListView.View | Should -BeOfType [System.Windows.Controls.GridView]
        $ListView.View.Columns.Count | Should -Be 2
    }
}
