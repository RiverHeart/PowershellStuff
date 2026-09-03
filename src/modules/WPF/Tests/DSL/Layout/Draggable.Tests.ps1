Describe 'Draggable' -Tag 'Draggable' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Item = [System.Windows.Controls.Label]::new()

        {
            -Draggable -InputObject $Item
        }.Invoke()
    }

    It 'Should error when the target cannot be resolved' {
        $psVars = New-WPFVariableList -AdditionalVariables @([psvariable]::new('this', $null))

        {
            { Draggable }.InvokeWithContext($null, $psVars) 2>&1 |
            Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord]}
        } | Should -Not -Throw
    }

    It 'Should not throw when wiring a Canvas child' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Item = [System.Windows.Controls.Label]::new()
        $Canvas.Children.Add($Item) | Out-Null

        { Draggable -InputObject $Item } | Should -Not -Throw
    }

    It 'Should reposition the target on drag via mouse events' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Item = [System.Windows.Controls.Label]::new()
        $Canvas.Children.Add($Item) | Out-Null
        [System.Windows.Controls.Canvas]::SetLeft($Item, 10)
        [System.Windows.Controls.Canvas]::SetTop($Item, 10)

        Draggable -InputObject $Item

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice

        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent
        $Item.RaiseEvent($DownArgs)

        $MoveArgs = [System.Windows.Input.MouseEventArgs]::new($MouseDevice, [Environment]::TickCount)
        $MoveArgs.RoutedEvent = [System.Windows.UIElement]::MouseMoveEvent
        $Item.RaiseEvent($MoveArgs)

        $UpArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $UpArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
        $Item.RaiseEvent($UpArgs)
    }

    It 'Should invoke -OnDragEnd after a completed drag' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Item = [System.Windows.Controls.Label]::new()
        $Canvas.Children.Add($Item) | Out-Null

        $script:DragEndedTarget = $null
        Draggable -InputObject $Item -OnDragEnd { param($Target) $script:DragEndedTarget = $Target }

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice

        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent
        $Item.RaiseEvent($DownArgs)

        $UpArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $UpArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
        $Item.RaiseEvent($UpArgs)

        $script:DragEndedTarget | Should -Be $Item
    }

    It 'Should warn and ignore drag start when the parent is not a Canvas' {
        $Parent = [System.Windows.Controls.StackPanel]::new()
        $Item = [System.Windows.Controls.Label]::new()
        $Parent.Children.Add($Item) | Out-Null

        Draggable -InputObject $Item

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice
        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent

        $Warnings = @(Invoke-Command -ScriptBlock { $Item.RaiseEvent($DownArgs) } -WarningVariable +Warnings 3>&1)
        ($Warnings | Out-String) | Should -Match 'must be attached to a Canvas'
    }
}
