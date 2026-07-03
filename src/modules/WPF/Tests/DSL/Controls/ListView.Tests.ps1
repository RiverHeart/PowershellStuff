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
}
