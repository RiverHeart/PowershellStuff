Describe 'Add-WpfDesignerLabel' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerLabel.ps1"
        . "$PSScriptRoot/../functions/Select-WpfDesignerElement.ps1"
        . "$PSScriptRoot/../functions/Clear-WpfDesignerSelection.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
    }

    It 'Should add a Label to the canvas and position it' {
        $Canvas = [System.Windows.Controls.Canvas]::new()

        $NewLabel = Add-WpfDesignerLabel -Canvas $Canvas -State @{ SelectedElement = $null }

        $Canvas.Children.Count | Should -Be -ExpectedValue 1
        $Canvas.Children[0] | Should -Be -ExpectedValue $NewLabel
        $NewLabel | Should -BeOfType [System.Windows.Controls.Label]
        $NewLabel.Content | Should -Be -ExpectedValue 'Label'
        [System.Windows.Controls.Canvas]::GetLeft($NewLabel) | Should -Be -ExpectedValue 20
        [System.Windows.Controls.Canvas]::GetTop($NewLabel) | Should -Be -ExpectedValue 20
    }

    It 'Should stagger placement for additional labels' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }

        Add-WpfDesignerLabel -Canvas $Canvas -State $State | Out-Null
        $Second = Add-WpfDesignerLabel -Canvas $Canvas -State $State

        [System.Windows.Controls.Canvas]::GetLeft($Second) | Should -Be -ExpectedValue 44
    }

    It 'Should make the added Label draggable' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $NewLabel = Add-WpfDesignerLabel -Canvas $Canvas -State @{ SelectedElement = $null }

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice
        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent

        { $NewLabel.RaiseEvent($DownArgs) } | Should -Not -Throw
    }
}
