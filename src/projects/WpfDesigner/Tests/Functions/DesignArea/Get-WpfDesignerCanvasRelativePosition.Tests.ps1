Describe 'Get-WpfDesignerCanvasRelativePosition' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WpfDesigner.psm1" -Force
    }

    It 'Should return the Canvas.Left/Top position for a direct canvas child' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        [System.Windows.Controls.Canvas]::SetLeft($Target, 15)
        [System.Windows.Controls.Canvas]::SetTop($Target, 25)
        $Canvas.Children.Add($Target) | Out-Null

        $Position = Get-WpfDesignerCanvasRelativePosition -Canvas $Canvas -Target $Target

        $Position.X | Should -Be -ExpectedValue 15
        $Position.Y | Should -Be -ExpectedValue 25
    }

    It 'Should default to (0,0) for a direct canvas child with no Canvas.Left/Top set' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Canvas.Children.Add($Target) | Out-Null

        $Position = Get-WpfDesignerCanvasRelativePosition -Canvas $Canvas -Target $Target

        $Position.X | Should -Be -ExpectedValue 0
        $Position.Y | Should -Be -ExpectedValue 0
    }

    It 'Should resolve position via TransformToVisual for a target nested inside a container' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $StackPanel = [System.Windows.Controls.StackPanel]::new()
        [System.Windows.Controls.Canvas]::SetLeft($StackPanel, 40)
        [System.Windows.Controls.Canvas]::SetTop($StackPanel, 30)
        $Canvas.Children.Add($StackPanel) | Out-Null

        # No explicit Width on the StackPanel, so it auto-sizes to the child's
        # width - otherwise HorizontalAlignment=Stretch on a narrower, explicitly
        # sized child centers it within the extra space instead of sitting flush
        # at the panel's origin, which would make this test's expected math wrong
        # rather than testing anything about Get-WpfDesignerCanvasRelativePosition.
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $StackPanel.Children.Add($Target) | Out-Null

        # TransformToVisual needs a completed layout pass to be accurate, same
        # as the resize handle's ActualWidth/ActualHeight-dependent tests.
        $HwndSourceParams = [System.Windows.Interop.HwndSourceParameters]::new('WpfDesignerCanvasRelativePositionTest')
        $HwndSourceParams.Width = 300
        $HwndSourceParams.Height = 300
        $HwndSource = [System.Windows.Interop.HwndSource]::new($HwndSourceParams)
        try {
            $HwndSource.RootVisual = $Canvas
            $Canvas.UpdateLayout()

            $Position = Get-WpfDesignerCanvasRelativePosition -Canvas $Canvas -Target $Target
        } finally {
            $HwndSource.Dispose()
        }

        $Position.X | Should -Be -ExpectedValue 40
        $Position.Y | Should -Be -ExpectedValue 30
    }
}
