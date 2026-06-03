BeforeDiscovery {
    Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force -ErrorAction Stop
}

Describe 'State' -Tag 'State' {
    It 'Should create observable state via New-WPFObservableState' {
        $result = New-WPFObservableState @{
            Count = 0
            IsReady = $false
        }

        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 0
        $result.IsReady | Should -Be $false
    }

    It 'Should initialize properties with correct values' {
        $result = New-WPFObservableState @{
            Count = 42
            IsReady = $true
            Name = 'test'
        }

        $result.Count | Should -Be 42
        $result.IsReady | Should -Be $true
        $result.Name | Should -Be 'test'
    }

    It 'Should support property updates' {
        $result = New-WPFObservableState @{
            Count = 0
        }

        $result.Count = 10
        $result.Count | Should -Be 10
    }

    It 'Should implement INotifyPropertyChanged for WPF binding' {
        $result = New-WPFObservableState @{
            Count = 0
        }

        $result -is [System.ComponentModel.INotifyPropertyChanged] | Should -BeTrue
        $result.Count | Should -Be 0
    }

    It 'Should support AddBinding method for PowerShell callbacks' {
        $result = New-WPFObservableState @{
            Count = 0
        }

        $changes = [System.Collections.Generic.List[object]]::new()

        # Keep this to one direct callback fire so the test stays stable.
        { $result.AddBinding('Count', { param($value) [void]$changes.Add($value) }, $false) } | Should -Not -Throw

        $result.Count = 10

        $changes.Count | Should -Be 1
        $changes[0] | Should -Be 10
    }

    It 'Should initialize Window.Tag when used inside a Window block' {
        $windowName = "Window_$([guid]::NewGuid().ToString('N'))"

        $null = Window $windowName {
            State @{
                Count = 3
                IsReady = $true
            }
        }

        $window = Reference $windowName

        $window.Tag | Should -Not -BeNullOrEmpty
        $window.Tag.Count | Should -Be 3
        $window.Tag.IsReady | Should -Be $true
    }

    It 'Should initialize Tag on other DSL parents with a Tag property' {
        $windowName = "Window_$([guid]::NewGuid().ToString('N'))"
        $buttonName = "Button_$([guid]::NewGuid().ToString('N'))"

        $null = Window $windowName {
            Button $buttonName {
                State @{
                    Count = 7
                }
            }
        }

        $button = Reference $buttonName

        $button.Tag | Should -Not -BeNullOrEmpty
        $button.Tag.Count | Should -Be 7
    }

    It 'Should allow multiple property bindings' {
        $result = New-WPFObservableState @{
            Count = 0
            IsActive = $false
        }

        $result.Count | Should -Be 0
        $result.IsActive | Should -Be $false

        $result.Count = 10
        $result.IsActive = $true

        $result.Count | Should -Be 10
        $result.IsActive | Should -Be $true
    }

    It 'Should create ExpandoObject state when requested' {
        $result = New-WPFObservableState -Properties @{
            ItemCount = 1
            Label = 'ok'
        } -Implementation ExpandoObject

        $result.ItemCount | Should -Be 1
        $result.Label | Should -Be 'ok'
        $result -is [System.ComponentModel.INotifyPropertyChanged] | Should -BeTrue
    }

    It 'Should auto-update WPF binding with ExpandoObject implementation' {
        $result = New-WPFObservableState -Properties @{
            ItemCount = 0
        } -Implementation ExpandoObject

        $textBlock = [System.Windows.Controls.TextBlock]::new()
        $textBlock.DataContext = $result
        $null = [System.Windows.Data.BindingOperations]::SetBinding(
            $textBlock,
            [System.Windows.Controls.TextBlock]::TextProperty,
            [System.Windows.Data.Binding]::new('ItemCount')
        )

        $textBlock.Text | Should -Be '0'

        $result.ItemCount = 25

        $textBlock.Text | Should -Be '25'
    }

    It 'Should create DynamicObject state when requested' {
        $result = New-WPFObservableState -Properties @{
            Count = 1
            Label = 'ok'
        } -Implementation DynamicObject

        $result.Count | Should -Be 1
        $result.Label | Should -Be 'ok'
        $result -is [System.ComponentModel.INotifyPropertyChanged] | Should -BeTrue
    }

    It 'Should auto-update WPF binding with DynamicObject implementation for Count' {
        $result = New-WPFObservableState -Properties @{
            Count = 0
        } -Implementation DynamicObject

        $textBlock = [System.Windows.Controls.TextBlock]::new()
        $textBlock.DataContext = $result
        $null = [System.Windows.Data.BindingOperations]::SetBinding(
            $textBlock,
            [System.Windows.Controls.TextBlock]::TextProperty,
            [System.Windows.Data.Binding]::new('Count')
        )

        $textBlock.Text | Should -Be '0'

        $result.Count = 17

        $textBlock.Text | Should -Be '17'
    }

    It 'Should use a dynamic notifying implementation by default' {
        $result = New-WPFObservableState @{
            ItemCount = 0
        }

        $result -is [System.ComponentModel.INotifyPropertyChanged] | Should -BeTrue

        $textBlock = [System.Windows.Controls.TextBlock]::new()
        $textBlock.DataContext = $result
        $null = [System.Windows.Data.BindingOperations]::SetBinding(
            $textBlock,
            [System.Windows.Controls.TextBlock]::TextProperty,
            [System.Windows.Data.Binding]::new('ItemCount')
        )

        $textBlock.Text | Should -Be '0'

        $result.ItemCount = 33

        $textBlock.Text | Should -Be '33'
    }
}
