Describe 'New-WpfDesignerWindowFrame' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/New-WpfDesignerWindowFrame.ps1"
        . "$PSScriptRoot/../functions/Select-WpfDesignerElement.ps1"
        . "$PSScriptRoot/../functions/Clear-WpfDesignerSelection.ps1"
        . "$PSScriptRoot/../functions/Add-PSType.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerSelectionOutline.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerSelectionOutlinePosition.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerCanvasRelativePosition.ps1"
    }

    It 'Should add a Border frame to the canvas and position it' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null; WindowFrame = $null }

        $Frame = New-WpfDesignerWindowFrame -Canvas $Canvas -State $State

        $Canvas.Children.Count | Should -Be -ExpectedValue 1
        $Canvas.Children[0] | Should -Be -ExpectedValue $Frame
        $Frame | Should -BeOfType [System.Windows.Controls.Border]
        [System.Windows.Controls.Canvas]::GetLeft($Frame) | Should -Be -ExpectedValue 20
        [System.Windows.Controls.Canvas]::GetTop($Frame) | Should -Be -ExpectedValue 20
    }

    It 'Should store the frame on State' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null; WindowFrame = $null }

        $Frame = New-WpfDesignerWindowFrame -Canvas $Canvas -State $State

        $State.WindowFrame | Should -Be -ExpectedValue $Frame
    }

    It 'Should associate the frame with a hidden Window property target' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null; WindowFrame = $null; WindowModel = $null }

        $Frame = New-WpfDesignerWindowFrame -Canvas $Canvas -State $State

        $State.WindowModel | Should -BeOfType [System.Windows.Window]
        $Frame._WPFDesignerPropertyTarget | Should -Be -ExpectedValue $State.WindowModel
    }

    It 'Should synchronize frame and Window dimensions in both directions' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null; WindowFrame = $null; WindowModel = $null }
        $Frame = New-WpfDesignerWindowFrame -Canvas $Canvas -State $State

        $State.WindowModel.Width = 640
        $Frame.Width | Should -Be -ExpectedValue 640

        $Frame.Height = 420
        $State.WindowModel.Height | Should -Be -ExpectedValue 420
    }

    It 'Should provide a Canvas as the frame''s default content root' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null; WindowFrame = $null; WindowModel = $null }

        $Frame = New-WpfDesignerWindowFrame -Canvas $Canvas -State $State

        $Frame.Child | Should -BeOfType [System.Windows.Controls.Canvas]
        $Frame._WPFDesignerContentRoot | Should -Be -ExpectedValue $Frame.Child
    }

    It 'Should select the frame and add a resize handle when clicked' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null; WindowFrame = $null }
        $Frame = New-WpfDesignerWindowFrame -Canvas $Canvas -State $State

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice
        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent
        $Frame.RaiseEvent($DownArgs)

        $State.SelectedElement | Should -Be -ExpectedValue $Frame
        $Canvas.Children.Count | Should -Be -ExpectedValue 3
        $DownArgs.Handled | Should -Be -ExpectedValue $true
    }

    It 'Should restore the frame''s chrome appearance after being deselected' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null; WindowFrame = $null }
        $Frame = New-WpfDesignerWindowFrame -Canvas $Canvas -State $State

        Select-WpfDesignerElement -Canvas $Canvas -Target $Frame -State $State
        Clear-WpfDesignerSelection -Canvas $Canvas -State $State

        $Frame.BorderBrush.ToString() | Should -Be -ExpectedValue '#FF666666'
        $Frame.BorderThickness.Left | Should -Be -ExpectedValue 2
    }
}
