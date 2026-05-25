Describe 'DataGrid' -Tag 'DataGrid' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -DataGrid "Grid_$Id" {}
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }

    It 'Should create a DataGrid with the given name' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = DataGrid "Grid_$Id" {}

        $Result | Should -BeOfType [System.Windows.Controls.DataGrid]
        $Result.Name | Should -Be "Grid_$Id"
    }

    It 'Should set ItemsSource via scriptblock' {
        $Id = [guid]::NewGuid().ToString('N')
        $Items = @(
            [pscustomobject] @{ Name = 'Alpha'; Value = 1 }
            [pscustomobject] @{ Name = 'Beta';  Value = 2 }
        )

        $Result = DataGrid "Grid_$Id" {
            $this.ItemsSource = $Items
        }

        $Result.ItemsSource | Should -Be $Items
    }
}
