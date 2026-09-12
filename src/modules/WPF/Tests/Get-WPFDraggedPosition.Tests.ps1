Describe 'Get-WPFDraggedPosition' -Tag 'Get-WPFDraggedPosition' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should add the mouse delta to the anchor position' {
        InModuleScope WPF {
            $Result = Get-WPFDraggedPosition `
                -AnchorLeft 10 `
                -AnchorTop 20 `
                -AnchorMouse ([System.Windows.Point]::new(5, 5)) `
                -CurrentMouse ([System.Windows.Point]::new(8, 2))

            $Result.Left | Should -Be 13
            $Result.Top | Should -Be 17
        }
    }

    It 'Should return the anchor position unchanged when the mouse has not moved' {
        InModuleScope WPF {
            $Result = Get-WPFDraggedPosition `
                -AnchorLeft 42 `
                -AnchorTop 7 `
                -AnchorMouse ([System.Windows.Point]::new(100, 200)) `
                -CurrentMouse ([System.Windows.Point]::new(100, 200))

            $Result.Left | Should -Be 42
            $Result.Top | Should -Be 7
        }
    }

    It 'Should support negative deltas' {
        InModuleScope WPF {
            $Result = Get-WPFDraggedPosition `
                -AnchorLeft 10 `
                -AnchorTop 10 `
                -AnchorMouse ([System.Windows.Point]::new(50, 50)) `
                -CurrentMouse ([System.Windows.Point]::new(20, 5))

            $Result.Left | Should -Be -20
            $Result.Top | Should -Be -35
        }
    }

    It 'Should clamp the result to -MaxLeft/-MaxTop when provided' {
        InModuleScope WPF {
            $Result = Get-WPFDraggedPosition `
                -AnchorLeft 90 `
                -AnchorTop 90 `
                -AnchorMouse ([System.Windows.Point]::new(0, 0)) `
                -CurrentMouse ([System.Windows.Point]::new(50, 50)) `
                -MaxLeft 100 `
                -MaxTop 100

            $Result.Left | Should -Be 100
            $Result.Top | Should -Be 100
        }
    }

    It 'Should clamp the result to 0 when a delta would go negative' {
        InModuleScope WPF {
            $Result = Get-WPFDraggedPosition `
                -AnchorLeft 10 `
                -AnchorTop 10 `
                -AnchorMouse ([System.Windows.Point]::new(50, 50)) `
                -CurrentMouse ([System.Windows.Point]::new(0, 0)) `
                -MaxLeft 100 `
                -MaxTop 100

            $Result.Left | Should -Be 0
            $Result.Top | Should -Be 0
        }
    }
}
