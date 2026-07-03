Describe 'GridViewColumn' -Tag 'GridViewColumn' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -GridViewColumn 'MyGridViewColumn' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create a GridViewColumn and apply scriptblock properties' {
        $Result = GridViewColumn {
            $this.Header = 'CPU'
            $this.Width = 120
        }

        $Result | Should -BeOfType [System.Windows.Controls.GridViewColumn]
        $Result.Header | Should -Be 'CPU'
        $Result.Width | Should -Be 120
    }

    It 'Should auto-attach GridViewColumn inside GridView' {
        $Result = GridView {
            GridViewColumn {
                $this.Header = 'Name'
            }
        }

        $Result.Columns.Count | Should -Be 1
        $Result.Columns[0].Header | Should -Be 'Name'
    }
}
