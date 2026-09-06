Describe 'TreeViewItem' -Tag 'TreeViewItem' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -TreeViewItem 'MyItem' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create a TreeViewItem with the given name' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = TreeViewItem "Item_$Id" {
            $this.Header = 'Hello'
        }

        $Result | Should -BeOfType [System.Windows.Controls.TreeViewItem]
        $Result.Name | Should -Be "Item_$Id"
        $Result.Header | Should -Be 'Hello'
    }

    It 'Should nest child TreeViewItem elements' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = TreeViewItem "Parent_$Id" {
            $this.Header = 'Parent'

            TreeViewItem "Child_$Id" {
                $this.Header = 'Child'
            }
        }

        $Result.Items.Count | Should -Be 1
        $Result.Items[0].Header | Should -Be 'Child'
    }
}
