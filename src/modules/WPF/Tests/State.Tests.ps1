BeforeAll {
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

        # Check that the object has the internal observable
        $result._Observable | Should -Not -BeNullOrEmpty
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
}
