# Tests for DataContext binding via State keyword

BeforeDiscovery {
    Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force -ErrorAction Stop
}

Describe 'State DataContext Binding' -Tag 'State' {
    It 'Should set DataContext and Tag to the same observable state object' {
        $window = Window "TestWindow_$([guid]::NewGuid().ToString('N'))" {
            State @{ Foo = 42; Bar = 'baz' }
        }
        $state = $window.DataContext
        $window.Tag | Should -Be $state
        $state.Foo | Should -Be 42
        $state.Bar | Should -Be 'baz'
    }

    It 'Should expose DataContext for standard WPF bindings' {
        InModuleScope WPF {
            Mock Write-Warning {}
        }

        $window = Window "TestWindow_$([guid]::NewGuid().ToString('N'))" {
            State @{ Count = 0 }
            $this.Content = [System.Windows.Controls.TextBlock]::new()
            $this.Content.DataContext = $this.DataContext
            $binding = [System.Windows.Data.Binding]::new('Count')
            $this.Content.SetBinding([System.Windows.Controls.TextBlock]::TextProperty, $binding)
        }

        $window.DataContext.Count = 99
        [System.Windows.Data.BindingOperations]::GetBindingExpression($window.Content, [System.Windows.Controls.TextBlock]::TextProperty).UpdateTarget()
        $window.Content.Text | Should -Be '99'

        InModuleScope WPF {
            Should -Invoke Write-Warning -Times 0 -Exactly
        }
    }

    It 'Should keep Tag and DataContext synchronized for backward compatibility' {
        $window = Window "TestWindow_$([guid]::NewGuid().ToString('N'))" {
            State @{ Value = 'abc' }
        }

        $window.Tag.Value = 'xyz'
        $window.DataContext.Value | Should -Be 'xyz'

        $window.DataContext.Value = 'uvw'
        $window.Tag.Value | Should -Be 'uvw'
    }

    It 'Should set DataContext on non-window DSL parents when available' {
        $buttonName = "Button_$([guid]::NewGuid().ToString('N'))"

        $window = Window "TestWindow_$([guid]::NewGuid().ToString('N'))" {
            Button $buttonName {
                State @{ Clicks = 5 }
            }
        }

        $button = Reference $buttonName

        $button.Tag | Should -Not -BeNullOrEmpty
        $button.DataContext | Should -Be $button.Tag
        $button.DataContext.Clicks | Should -Be 5
    }
}
