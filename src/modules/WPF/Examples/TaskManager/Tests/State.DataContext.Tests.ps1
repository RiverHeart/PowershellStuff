# Tests for State keyword DataContext integration

Describe 'State keyword DataContext integration' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        . "$PSScriptRoot/../functions/New-ColumnHeaderTemplate.ps1"
    }

    It 'Should set DataContext and Tag to the same observable state object on Window' {
        $window = Window 'TestWindow' {
            State @{ Foo = 42; Bar = 'baz' }
        }
        $state = $window.Tag
        $window.DataContext | Should -Be $state
        $state.Foo | Should -Be 42
        $state.Bar | Should -Be 'baz'
    }

    It 'Should allow WPF binding to DataContext property' {
        $window = Window 'TestWindow' {
            State @{ Foo = 123 }
            TextBlock 'BoundText' {
                $this.SetBinding([System.Windows.Controls.TextBlock]::TextProperty, [System.Windows.Data.Binding]::new('Foo'))
            }
        }
        $window.DataContext.Foo = 456
        $textBlock = Reference 'BoundText'
        # Force WPF to update bindings
        [System.Windows.Data.BindingOperations]::GetBindingExpression($textBlock, [System.Windows.Controls.TextBlock]::TextProperty).UpdateTarget()
        $textBlock.Text | Should -Be '456'
    }

    It 'Should not break Tag-based access for backward compatibility' {
        $window = Window 'TestWindow' {
            State @{ OldWay = 'still works' }
        }
        $window.Tag.OldWay | Should -Be 'still works'
    }

    It 'Should bind column header totals through Window.DataContext' {
        $template = New-ColumnHeaderTemplate -TotalPropertyPath 'TotalCpuPercent' -Label 'CPU'
        $template.Seal()
        $root = $template.LoadContent()
        $totalBlock = $root.Children[0]

        $binding = [System.Windows.Data.BindingOperations]::GetBinding($totalBlock, [System.Windows.Controls.TextBlock]::TextProperty)

        $binding | Should -Not -BeNullOrEmpty
        $binding.Path.Path | Should -Be 'DataContext.TotalCpuPercent'
        $binding.RelativeSource.Mode | Should -Be ([System.Windows.Data.RelativeSourceMode]::FindAncestor)
        $binding.RelativeSource.AncestorType | Should -Be ([System.Windows.Window])
    }
}
