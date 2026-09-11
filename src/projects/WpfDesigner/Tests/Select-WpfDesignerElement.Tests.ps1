Describe 'Select-WpfDesignerElement' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Select-WpfDesignerElement.ps1"
        . "$PSScriptRoot/../functions/Clear-WpfDesignerSelection.ps1"
        . "$PSScriptRoot/../functions/Add-PSType.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerSelectionOutline.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerSelectionOutlinePosition.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerCanvasRelativePosition.ps1"
        . "$PSScriptRoot/../functions/Add-WpfDesignerEnterCommit.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerEditorKind.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerPropertyDescriptor.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerPropertyEditor.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerPropertyPanel.ps1"
    }

    It 'Should populate the property panel for the newly selected target when -Panel is supplied' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.TextBlock]::new()
        $Canvas.Children.Add($Target) | Out-Null
        $State = @{ SelectedElement = $null }
        $Panel = [System.Windows.Controls.StackPanel]::new()

        Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State -Panel $Panel

        $ExpectedRowCount = @(Get-WpfDesignerPropertyDescriptor -InputObject $Target).Count * 2
        $Panel.Children.Count | Should -Be -ExpectedValue $ExpectedRowCount
    }

    It 'Should leave the property panel untouched when -Panel is not supplied' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.TextBlock]::new()
        $Canvas.Children.Add($Target) | Out-Null
        $State = @{ SelectedElement = $null }

        { Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State } | Should -Not -Throw
    }

    It 'Should mark the target as selected and add a selection outline and resize handle' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null
        $State = @{ SelectedElement = $null }

        Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State

        $State.SelectedElement | Should -Be -ExpectedValue $Target
        $Canvas.Children.Count | Should -Be -ExpectedValue 3
        $Outline = $Target._WPFDesignerSelectionOutline
        $Outline | Should -BeOfType [System.Windows.Controls.Border]
        $Outline.Width | Should -Be -ExpectedValue 100
        $Outline.Height | Should -Be -ExpectedValue 26
    }

    It 'Should move the resize handle and outline when selecting a different target' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $First = [System.Windows.Controls.Label]::new()
        $First.Width = 100
        $First.Height = 26
        $Second = [System.Windows.Controls.Label]::new()
        $Second.Width = 100
        $Second.Height = 26
        $Canvas.Children.Add($First) | Out-Null
        $Canvas.Children.Add($Second) | Out-Null
        $State = @{ SelectedElement = $null }

        Select-WpfDesignerElement -Canvas $Canvas -Target $First -State $State
        Select-WpfDesignerElement -Canvas $Canvas -Target $Second -State $State

        $State.SelectedElement | Should -Be -ExpectedValue $Second
        $Canvas.Children.Count | Should -Be -ExpectedValue 4
        $Second._WPFDesignerSelectionOutline | Should -Not -Be -ExpectedValue $null
    }

    It 'Should be a no-op when re-selecting the already-selected target' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null
        $State = @{ SelectedElement = $null }

        Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State
        Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State

        $Canvas.Children.Count | Should -Be -ExpectedValue 3
    }

    It 'Should select a StackPanel (no BorderBrush of its own) without throwing' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.StackPanel]::new()
        $Target.Width = 160
        $Target.Height = 120
        $Canvas.Children.Add($Target) | Out-Null
        $State = @{ SelectedElement = $null }

        { Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State } | Should -Not -Throw

        $State.SelectedElement | Should -Be -ExpectedValue $Target
        $Outline = $Target._WPFDesignerSelectionOutline
        $Outline.Width | Should -Be -ExpectedValue 160
        $Outline.Height | Should -Be -ExpectedValue 120
    }
}

Describe 'Clear-WpfDesignerSelection' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Select-WpfDesignerElement.ps1"
        . "$PSScriptRoot/../functions/Clear-WpfDesignerSelection.ps1"
        . "$PSScriptRoot/../functions/Add-PSType.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerSelectionOutline.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerSelectionOutlinePosition.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerCanvasRelativePosition.ps1"
        . "$PSScriptRoot/../functions/Add-WpfDesignerEnterCommit.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerEditorKind.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerPropertyDescriptor.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerPropertyEditor.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerPropertyPanel.ps1"
    }

    It 'Should empty the property panel when clearing selection with -Panel supplied' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null
        $State = @{ SelectedElement = $null }
        $Panel = [System.Windows.Controls.StackPanel]::new()
        Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State -Panel $Panel

        Clear-WpfDesignerSelection -Canvas $Canvas -State $State -Panel $Panel

        $Panel.Children.Count | Should -Be -ExpectedValue 0
    }

    It 'Should remove the outline and resize handle and clear selection state' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null
        $State = @{ SelectedElement = $null }
        Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State

        Clear-WpfDesignerSelection -Canvas $Canvas -State $State

        $State.SelectedElement | Should -Be -ExpectedValue $null
        $Canvas.Children.Count | Should -Be -ExpectedValue 1
    }

    It 'Should be a no-op when nothing is selected' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $State = @{ SelectedElement = $null }

        { Clear-WpfDesignerSelection -Canvas $Canvas -State $State } | Should -Not -Throw
    }

    It 'Should never modify a Border target''s own BorderBrush/BorderThickness' {
        # Selection highlight is a separate overlay (New-WpfDesignerSelectionOutline)
        # rather than a mutation of the target, so a Border target's own local
        # BorderBrush/BorderThickness (e.g. the Window frame's chrome) must be left
        # untouched across a select/clear cycle.
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Border]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Target.BorderBrush = 'Black'
        $Target.BorderThickness = 3
        $Canvas.Children.Add($Target) | Out-Null
        $State = @{ SelectedElement = $null }

        Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State
        Clear-WpfDesignerSelection -Canvas $Canvas -State $State

        $Target.BorderBrush.ToString() | Should -Be -ExpectedValue '#FF000000'
        $Target.BorderThickness.Left | Should -Be -ExpectedValue 3
    }
}

Describe 'New-WpfDesignerSelectionOutline' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-PSType.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerSelectionOutline.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerSelectionOutlinePosition.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerCanvasRelativePosition.ps1"
    }

    It 'Should not be hit-test visible, so it never intercepts clicks meant for the target' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null

        $Outline = New-WpfDesignerSelectionOutline -Canvas $Canvas -Target $Target

        $Outline.IsHitTestVisible | Should -Be -ExpectedValue $false
    }

    It 'Should reposition the outline when the target size changes without a drag' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null

        $Outline = New-WpfDesignerSelectionOutline -Canvas $Canvas -Target $Target

        $HwndSourceParams = [System.Windows.Interop.HwndSourceParameters]::new('WpfDesignerSelectionOutlineTest')
        $HwndSourceParams.Width = 300
        $HwndSourceParams.Height = 300
        $HwndSource = [System.Windows.Interop.HwndSource]::new($HwndSourceParams)
        try {
            $HwndSource.RootVisual = $Canvas
            $Canvas.UpdateLayout()

            $Target.Width = 160
            $Target.Height = 40
            $Canvas.UpdateLayout()
        } finally {
            $HwndSource.Dispose()
        }

        $Outline.Width | Should -Be -ExpectedValue 160
        $Outline.Height | Should -Be -ExpectedValue 40
    }
}


Describe 'New-WpfDesignerResizeHandle' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-PSType.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerCanvasRelativePosition.ps1"
    }

    It 'Should resize the target when the handle is dragged' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null

        $Handle = New-WpfDesignerResizeHandle -Canvas $Canvas -Target $Target

        $DeltaArgs = [System.Windows.Controls.Primitives.DragDeltaEventArgs]::new(15, 10)
        $DeltaArgs.RoutedEvent = [System.Windows.Controls.Primitives.Thumb]::DragDeltaEvent

        { $Handle.RaiseEvent($DeltaArgs) } | Should -Not -Throw
        $Target.Width | Should -Be -ExpectedValue 115
        $Target.Height | Should -Be -ExpectedValue 36
    }

    It 'Should clamp target size to a 20px minimum' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null

        $Handle = New-WpfDesignerResizeHandle -Canvas $Canvas -Target $Target

        $DeltaArgs = [System.Windows.Controls.Primitives.DragDeltaEventArgs]::new(-500, -500)
        $DeltaArgs.RoutedEvent = [System.Windows.Controls.Primitives.Thumb]::DragDeltaEvent
        $Handle.RaiseEvent($DeltaArgs)

        $Target.Width | Should -Be -ExpectedValue 20
        $Target.Height | Should -Be -ExpectedValue 20
    }

    It 'Should reposition the handle when the target size changes without a drag' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null

        $Handle = New-WpfDesignerResizeHandle -Canvas $Canvas -Target $Target

        # SizeChanged requires a real PresentationSource to fire, so host the
        # canvas in an invisible native window instead of a full app Show().
        $HwndSourceParams = [System.Windows.Interop.HwndSourceParameters]::new('WpfDesignerTest')
        $HwndSourceParams.Width = 300
        $HwndSourceParams.Height = 300
        $HwndSource = [System.Windows.Interop.HwndSource]::new($HwndSourceParams)
        try {
            $HwndSource.RootVisual = $Canvas
            $Canvas.UpdateLayout()

            $Target.Width = 160
            $Target.Height = 40
            $Canvas.UpdateLayout()
        } finally {
            $HwndSource.Dispose()
        }

        [System.Windows.Controls.Canvas]::GetLeft($Handle) | Should -Be -ExpectedValue (160 - ($Handle.Width / 2))
        [System.Windows.Controls.Canvas]::GetTop($Handle) | Should -Be -ExpectedValue (40 - ($Handle.Height / 2))
    }

    It 'Should clamp resize to the canvas''s actual bounds once laid out' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        [System.Windows.Controls.Canvas]::SetLeft($Target, 250)
        [System.Windows.Controls.Canvas]::SetTop($Target, 260)
        $Canvas.Children.Add($Target) | Out-Null

        $Handle = New-WpfDesignerResizeHandle -Canvas $Canvas -Target $Target

        $HwndSourceParams = [System.Windows.Interop.HwndSourceParameters]::new('WpfDesignerResizeClampTest')
        $HwndSourceParams.Width = 300
        $HwndSourceParams.Height = 300
        $HwndSource = [System.Windows.Interop.HwndSource]::new($HwndSourceParams)
        try {
            $HwndSource.RootVisual = $Canvas
            $Canvas.Width = 300
            $Canvas.Height = 300
            $Canvas.UpdateLayout()

            # Target sits at (250, 260) in a 300x300 canvas, so only 50x40 of
            # room remains before hitting the canvas edge.
            $DeltaArgs = [System.Windows.Controls.Primitives.DragDeltaEventArgs]::new(500, 500)
            $DeltaArgs.RoutedEvent = [System.Windows.Controls.Primitives.Thumb]::DragDeltaEvent
            $Handle.RaiseEvent($DeltaArgs)
        } finally {
            $HwndSource.Dispose()
        }

        $Target.Width | Should -Be -ExpectedValue 50
        $Target.Height | Should -Be -ExpectedValue 40
    }
}
