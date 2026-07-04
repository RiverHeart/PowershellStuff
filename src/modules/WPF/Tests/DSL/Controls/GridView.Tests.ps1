Describe 'GridView' -Tag 'GridView' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -GridView 'MyGridView' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create a GridView' {
        $Result = GridView {}

        $Result | Should -BeOfType [System.Windows.Controls.GridView]
    }

    It 'Should attach GridViewColumn children' {
        $Result = GridView {
            GridViewColumn {
                $this.Header = 'Name'
            }
            GridViewColumn {
                $this.Header = 'Id'
            }
        }

        $Result.Columns.Count | Should -Be 2
        $Result.Columns[0].Header | Should -Be 'Name'
        $Result.Columns[1].Header | Should -Be 'Id'
    }
}
