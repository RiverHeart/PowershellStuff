Describe 'TreeView' -Tag 'TreeView' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -TreeView 'MyTreeView' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create a TreeView with the given name' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = TreeView "TreeView_$Id" {}

        $Result | Should -BeOfType [System.Windows.Controls.TreeView]
        $Result.Name | Should -Be "TreeView_$Id"
    }

    It 'Should attach nested TreeViewItem children' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = TreeView "TreeView_$Id" {
            TreeViewItem "Root_$Id" {
                $this.Header = 'Root'
            }
        }

        $Result.Items.Count | Should -Be 1
        $Result.Items[0].Header | Should -Be 'Root'
    }
}
