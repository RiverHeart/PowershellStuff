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
}
