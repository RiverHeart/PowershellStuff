Describe 'HierarchicalItemTemplate' -Tag 'HierarchicalItemTemplate' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should attach a HierarchicalDataTemplate to the parent TreeView ItemTemplate' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = TreeView "TreeView_$Id" {
            HierarchicalItemTemplate 'Children' {
                TextBlock {}
            }
        }

        $Result.ItemTemplate | Should -BeOfType [System.Windows.HierarchicalDataTemplate]
    }

    It 'Should bind ItemsSource to the given children property' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = TreeView "TreeView_$Id" {
            HierarchicalItemTemplate 'Children' {
                TextBlock {}
            }
        }

        $Result.ItemTemplate.ItemsSource.Path.Path | Should -Be 'Children'
    }

    It 'Should build a TextBlock visual tree bound to a data property' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = TreeView "TreeView_$Id" {
            HierarchicalItemTemplate 'Children' {
                TextBlock {
                    BindProperty Text Header
                }
            }
        }

        $Result.ItemTemplate.VisualTree.Type | Should -Be ([System.Windows.Controls.TextBlock])

        $Result.ItemTemplate.Seal()
        $Node = $Result.ItemTemplate.LoadContent()

        $Node | Should -BeOfType [System.Windows.Controls.TextBlock]

        $BindingApplied = [System.Windows.Data.BindingOperations]::GetBinding($Node, [System.Windows.Controls.TextBlock]::TextProperty)
        $BindingApplied.Path.Path | Should -Be 'Header'
    }

    It 'Should also attach when nested inside a TreeViewItem' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = TreeViewItem "Item_$Id" {
            $this.Header = 'Root'

            HierarchicalItemTemplate 'Children' {
                TextBlock {
                    BindProperty Text Header
                }
            }
        }

        $Result.ItemTemplate | Should -BeOfType [System.Windows.HierarchicalDataTemplate]
    }
}
