Describe 'Add-WpfDesignerStackPanel' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerContainerMarker.ps1"
        . "$PSScriptRoot/../functions/Test-WpfDesignerContainer.ps1"
        . "$PSScriptRoot/../functions/Test-WpfDesignerContainerCapacity.ps1"
        . "$PSScriptRoot/../functions/Add-WpfDesignerControl.ps1"
        . "$PSScriptRoot/../functions/Add-WpfDesignerStackPanel.ps1"
        . "$PSScriptRoot/../functions/Select-WpfDesignerElement.ps1"
        . "$PSScriptRoot/../functions/Clear-WpfDesignerSelection.ps1"
        . "$PSScriptRoot/../functions/Add-WpfDesignerOverlayMarker.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerSelectionOutline.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerSelectionOutlinePosition.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerCanvasRelativePosition.ps1"
    }

    It 'Should add a StackPanel to the canvas and position it' {
        $Canvas = [System.Windows.Controls.Canvas]::new()

        $NewStackPanel = Add-WpfDesignerStackPanel -Canvas $Canvas -State @{ SelectedElement = $null }

        $Canvas.Children.Count | Should -Be -ExpectedValue 1
        $Canvas.Children[0] | Should -Be -ExpectedValue $NewStackPanel
        $NewStackPanel | Should -BeOfType [System.Windows.Controls.StackPanel]
        $NewStackPanel.Width | Should -Be -ExpectedValue 160
        $NewStackPanel.Height | Should -Be -ExpectedValue 120
        [System.Windows.Controls.Canvas]::GetLeft($NewStackPanel) | Should -Be -ExpectedValue 20
        [System.Windows.Controls.Canvas]::GetTop($NewStackPanel) | Should -Be -ExpectedValue 20
    }

    It 'Should stagger placement for additional stack panels' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }

        Add-WpfDesignerStackPanel -Canvas $Canvas -State $State | Out-Null
        $Second = Add-WpfDesignerStackPanel -Canvas $Canvas -State $State

        [System.Windows.Controls.Canvas]::GetLeft($Second) | Should -Be -ExpectedValue 44
    }

    It 'Should be selectable without throwing even though StackPanel has no BorderBrush of its own' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $NewStackPanel = Add-WpfDesignerStackPanel -Canvas $Canvas -State @{ SelectedElement = $null }
        $State = @{ SelectedElement = $null }

        { Select-WpfDesignerElement -Canvas $Canvas -Target $NewStackPanel -State $State } | Should -Not -Throw
        $State.SelectedElement | Should -Be -ExpectedValue $NewStackPanel
    }

    It 'Should make the added StackPanel draggable' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $NewStackPanel = Add-WpfDesignerStackPanel -Canvas $Canvas -State @{ SelectedElement = $null }

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice
        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent

        { $NewStackPanel.RaiseEvent($DownArgs) } | Should -Not -Throw
    }
}
