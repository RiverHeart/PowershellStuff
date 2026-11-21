Describe 'Add-WpfDesignerControl container-aware placement' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WpfDesigner.psm1" -Force
    }

    It 'Should float on the canvas when nothing is selected' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }

        $NewLabel = Add-WpfDesignerLabel -Canvas $Canvas -State $State

        $NewLabel.Parent | Should -Be -ExpectedValue $Canvas
    }

    It 'Should nest the new element inside a selected StackPanel container' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }
        $StackPanel = Add-WpfDesignerStackPanel -Canvas $Canvas -State $State
        $State.SelectedElement = $StackPanel

        $NewLabel = Add-WpfDesignerLabel -Canvas $Canvas -State $State

        $NewLabel.Parent | Should -Be -ExpectedValue $StackPanel
        $Canvas.Children | Should -Not -Contain $NewLabel
    }

    It 'Should add and select a draggable element in the selected Window frame''s default Canvas' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null; WindowFrame = $null; WindowModel = $null }
        $Frame = New-WpfDesignerWindowFrame -Canvas $Canvas -State $State
        $State.SelectedElement = $Frame

        $NewLabel = Add-WpfDesignerLabel -Canvas $Canvas -State $State

        $NewLabel.Parent | Should -Be -ExpectedValue $Frame._WPFDesignerContentRoot
        [System.Windows.Controls.Canvas]::GetLeft($NewLabel) | Should -Be -ExpectedValue 20

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice
        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent
        $NewLabel.RaiseEvent($DownArgs)

        $State.SelectedElement | Should -Be -ExpectedValue $NewLabel
        $DownArgs.Handled | Should -Be -ExpectedValue $true
    }

    It 'Should fall back to floating when the selected Border container already has a child' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Frame = [System.Windows.Controls.Border]::new()
        Add-PSType -InputObject $Frame -TypeName 'Custom.WpfDesigner.Container'
        $Frame.Child = [System.Windows.Controls.Label]::new()
        $Canvas.Children.Add($Frame) | Out-Null
        $State = @{ SelectedElement = $Frame }

        $NewLabel = Add-WpfDesignerLabel -Canvas $Canvas -State $State

        $NewLabel.Parent | Should -Be -ExpectedValue $Canvas
    }

    It 'Should fall back to floating when the selection is not a valid container' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }
        $ExistingLabel = Add-WpfDesignerLabel -Canvas $Canvas -State $State
        $State.SelectedElement = $ExistingLabel

        $NewLabel = Add-WpfDesignerLabel -Canvas $Canvas -State $State

        $NewLabel.Parent | Should -Be -ExpectedValue $Canvas
    }

    It 'Should mark a new StackPanel as a valid container' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }

        $StackPanel = Add-WpfDesignerStackPanel -Canvas $Canvas -State $State

        Test-PSType -InputObject $StackPanel -TypeName 'Custom.WpfDesigner.Container' | Should -Be -ExpectedValue $true
    }

    It 'Should retain a nested Label selection and update the property panel when its click bubbles' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }
        $Panel = [System.Windows.Controls.StackPanel]::new()
        $StackPanel = Add-WpfDesignerStackPanel -Canvas $Canvas -State $State -Panel $Panel
        $State.SelectedElement = $StackPanel
        $Label = Add-WpfDesignerLabel -Canvas $Canvas -State $State -Panel $Panel

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice
        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent
        $Label.RaiseEvent($DownArgs)

        $State.SelectedElement | Should -Be -ExpectedValue $Label
        $DownArgs.Handled | Should -Be -ExpectedValue $true
        $Descriptors = @(Get-WpfDesignerPropertyDescriptor -InputObject $Label)
        $Panel.Children.Count | Should -Be -ExpectedValue @($Descriptors | Group-Object Category).Count
    }

    It 'Should retain a nested StackPanel selection when its click bubbles' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }
        $Outer = Add-WpfDesignerStackPanel -Canvas $Canvas -State $State
        $State.SelectedElement = $Outer
        $Inner = Add-WpfDesignerStackPanel -Canvas $Canvas -State $State

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice
        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent
        $Inner.RaiseEvent($DownArgs)

        $State.SelectedElement | Should -Be -ExpectedValue $Inner
        $DownArgs.Handled | Should -Be -ExpectedValue $true
    }

    It 'Should select a root container when the container itself is clicked' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }
        $Outer = Add-WpfDesignerStackPanel -Canvas $Canvas -State $State
        $State.SelectedElement = $Outer
        $Label = Add-WpfDesignerLabel -Canvas $Canvas -State $State

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice
        $ChildDownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $ChildDownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent
        $Label.RaiseEvent($ChildDownArgs)

        $ContainerDownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $ContainerDownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent
        $Outer.RaiseEvent($ContainerDownArgs)

        $State.SelectedElement | Should -Be -ExpectedValue $Outer
        $ContainerDownArgs.Handled | Should -Be -ExpectedValue $true
    }
}
