Describe 'Move-WpfDesignerElement' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WpfDesigner.psm1" -Force
    }

    It 'Should move a nested Label to the root Canvas at its visual position and reselect it' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Container = [System.Windows.Controls.StackPanel]::new()
        [System.Windows.Controls.Canvas]::SetLeft($Container, 40)
        [System.Windows.Controls.Canvas]::SetTop($Container, 30)
        $Canvas.Children.Add($Container) | Out-Null

        $Element = [System.Windows.Controls.Label]::new()
        $Element.Width = 100
        $Element.Height = 26
        $Container.Children.Add($Element) | Out-Null
        $State = @{ SelectedElement = $null; WindowFrame = $null }
        Select-WpfDesignerElement -Canvas $Canvas -Target $Element -State $State
        $PreviousOutline = $Element._WPFDesignerSelectionOutline
        $PreviousHandle = $Element._WPFDesignerResizeHandle

        $HwndSourceParams = [System.Windows.Interop.HwndSourceParameters]::new('MoveWpfDesignerElementTest')
        $HwndSourceParams.Width = 300
        $HwndSourceParams.Height = 300
        $HwndSource = [System.Windows.Interop.HwndSource]::new($HwndSourceParams)
        try {
            $HwndSource.RootVisual = $Canvas
            $Canvas.UpdateLayout()

            $Result = Move-WpfDesignerElement -Element $Element -TargetContainer $Canvas -State $State
        } finally {
            $HwndSource.Dispose()
        }

        $Result | Should -Be -ExpectedValue $Element
        $Element.Parent | Should -Be -ExpectedValue $Canvas
        [System.Windows.Controls.Canvas]::GetLeft($Element) | Should -Be -ExpectedValue 40
        [System.Windows.Controls.Canvas]::GetTop($Element) | Should -Be -ExpectedValue 30
        $State.SelectedElement | Should -Be -ExpectedValue $Element
        $Element._WPFDesignerSelectionOutline.Parent | Should -Be -ExpectedValue $Canvas
        $Element._WPFDesignerResizeHandle.Parent | Should -Be -ExpectedValue $Canvas
        $Element._WPFDesignerSelectionOutline | Should -Not -Be -ExpectedValue $PreviousOutline
        $Element._WPFDesignerResizeHandle | Should -Not -Be -ExpectedValue $PreviousHandle
        $PreviousOutline.Parent | Should -Be $null
        $PreviousHandle.Parent | Should -Be $null
        @(Get-WpfDesignerContainerChildren -Element $Canvas |
            Where-Object { Test-PSType -InputObject $_ -TypeName 'Custom.WpfDesigner.Overlay' }).Count |
            Should -Be -ExpectedValue 0
        @($Canvas.Children |
            Where-Object { Test-PSType -InputObject $_ -TypeName 'Custom.WpfDesigner.Overlay' }).Count |
            Should -Be -ExpectedValue 2
    }

    It 'Should preserve a StackPanel subtree and child order' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Outer = [System.Windows.Controls.StackPanel]::new()
        $Subtree = [System.Windows.Controls.StackPanel]::new()
        $First = [System.Windows.Controls.Label]::new()
        $Second = [System.Windows.Controls.Label]::new()
        $Subtree.Children.Add($First) | Out-Null
        $Subtree.Children.Add($Second) | Out-Null
        $Outer.Children.Add($Subtree) | Out-Null
        $Canvas.Children.Add($Outer) | Out-Null
        $State = @{ SelectedElement = $Subtree; WindowFrame = $null }

        Move-WpfDesignerElement -Element $Subtree -TargetContainer $Canvas -State $State | Out-Null

        $Subtree.Parent | Should -Be -ExpectedValue $Canvas
        $Subtree.Children.Count | Should -Be -ExpectedValue 2
        $Subtree.Children[0] | Should -Be -ExpectedValue $First
        $Subtree.Children[1] | Should -Be -ExpectedValue $Second
    }

    It 'Should move an element out of a Border child slot' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Border = [System.Windows.Controls.Border]::new()
        $Element = [System.Windows.Controls.Label]::new()
        $Border.Child = $Element
        $Canvas.Children.Add($Border) | Out-Null
        $State = @{ SelectedElement = $Element; WindowFrame = $null }

        Move-WpfDesignerElement -Element $Element -TargetContainer $Canvas -State $State | Out-Null

        $Border.Child | Should -Be $null
        $Element.Parent | Should -Be -ExpectedValue $Canvas
    }

    It 'Should reactivate existing Draggable handlers after moving to a Canvas' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null; WindowFrame = $null }
        $Container = Add-WpfDesignerStackPanel -Canvas $Canvas -State $State
        $State.SelectedElement = $Container
        $Element = Add-WpfDesignerLabel -Canvas $Canvas -State $State

        Move-WpfDesignerElement -Element $Element -TargetContainer $Canvas -State $State | Out-Null

        $MouseDevice = [System.Windows.Input.Mouse]::PrimaryDevice
        $DownArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $DownArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonDownEvent
        $Warnings = @(& { $Element.RaiseEvent($DownArgs) } 3>&1)

        $DownArgs.Handled | Should -Be -ExpectedValue $true
        $Warnings.Count | Should -Be -ExpectedValue 0

        $UpArgs = [System.Windows.Input.MouseButtonEventArgs]::new($MouseDevice, [Environment]::TickCount, [System.Windows.Input.MouseButton]::Left)
        $UpArgs.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
        $Element.RaiseEvent($UpArgs)
    }

    It 'Should reject an element already on the target Canvas without changing selection' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Element = [System.Windows.Controls.Label]::new()
        $Canvas.Children.Add($Element) | Out-Null
        $State = @{ SelectedElement = $Element; WindowFrame = $null }

        { Move-WpfDesignerElement -Element $Element -TargetContainer $Canvas -State $State } |
            Should -Throw '*already a direct child*'

        $Element.Parent | Should -Be -ExpectedValue $Canvas
        $State.SelectedElement | Should -Be -ExpectedValue $Element
    }

    It 'Should reject an unsupported target before changing the source tree or selection' {
        $Source = [System.Windows.Controls.StackPanel]::new()
        $Target = [System.Windows.Controls.StackPanel]::new()
        $Element = [System.Windows.Controls.Label]::new()
        $Source.Children.Add($Element) | Out-Null
        $State = @{ SelectedElement = $Element; WindowFrame = $null }

        { Move-WpfDesignerElement -Element $Element -TargetContainer $Target -State $State } |
            Should -Throw '*target container type*not supported*'

        $Element.Parent | Should -Be -ExpectedValue $Source
        $State.SelectedElement | Should -Be -ExpectedValue $Element
    }

    It 'Should reject the Window frame and design-time overlays without changing their parents' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Container = [System.Windows.Controls.StackPanel]::new()
        $Frame = [System.Windows.Controls.Border]::new()
        $Overlay = [System.Windows.Controls.Border]::new()
        Add-PSType -InputObject $Overlay -TypeName 'Custom.WpfDesigner.Overlay'
        $Container.Children.Add($Frame) | Out-Null
        $Container.Children.Add($Overlay) | Out-Null
        $Canvas.Children.Add($Container) | Out-Null
        $State = @{ SelectedElement = $Frame; WindowFrame = $Frame }

        { Move-WpfDesignerElement -Element $Frame -TargetContainer $Canvas -State $State } |
            Should -Throw '*Window frame*'
        { Move-WpfDesignerElement -Element $Overlay -TargetContainer $Canvas -State $State } |
            Should -Throw '*overlays*'

        $Frame.Parent | Should -Be -ExpectedValue $Container
        $Overlay.Parent | Should -Be -ExpectedValue $Container
        $State.SelectedElement | Should -Be -ExpectedValue $Frame
    }

    It 'Should restore source order and selection when target insertion fails' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Source = [System.Windows.Controls.StackPanel]::new()
        $Before = [System.Windows.Controls.Label]::new()
        $Element = [System.Windows.Controls.Label]::new()
        $After = [System.Windows.Controls.Label]::new()
        $Source.Children.Add($Before) | Out-Null
        $Source.Children.Add($Element) | Out-Null
        $Source.Children.Add($After) | Out-Null
        $Canvas.Children.Add($Source) | Out-Null
        $State = @{ SelectedElement = $null; WindowFrame = $null }
        Select-WpfDesignerElement -Canvas $Canvas -Target $Element -State $State

        Mock Add-WPFObject -ModuleName WpfDesigner {
            throw 'Simulated target insertion failure.'
        } -ParameterFilter { $ChildObjects -eq $Element }

        { Move-WpfDesignerElement -Element $Element -TargetContainer $Canvas -State $State } |
            Should -Throw '*Simulated target insertion failure*'

        $Element.Parent | Should -Be -ExpectedValue $Source
        $Source.Children[0] | Should -Be -ExpectedValue $Before
        $Source.Children[1] | Should -Be -ExpectedValue $Element
        $Source.Children[2] | Should -Be -ExpectedValue $After
        $State.SelectedElement | Should -Be -ExpectedValue $Element
        @($Canvas.Children |
            Where-Object { Test-PSType -InputObject $_ -TypeName 'Custom.WpfDesigner.Overlay' }).Count |
            Should -Be -ExpectedValue 2
    }
}
