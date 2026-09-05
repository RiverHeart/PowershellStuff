Describe 'Select-WpfDesignerElement' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Select-WpfDesignerElement.ps1"
        . "$PSScriptRoot/../functions/Clear-WpfDesignerSelection.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
    }

    It 'Should mark the target as selected and add a resize handle' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $Target.Height = 26
        $Canvas.Children.Add($Target) | Out-Null
        $State = @{ SelectedElement = $null }

        Select-WpfDesignerElement -Canvas $Canvas -Target $Target -State $State

        $State.SelectedElement | Should -Be -ExpectedValue $Target
        $Canvas.Children.Count | Should -Be -ExpectedValue 2
        $Target.BorderThickness.Left | Should -Be -ExpectedValue 2
    }

    It 'Should move the resize handle when selecting a different target' {
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
        $Canvas.Children.Count | Should -Be -ExpectedValue 3
        [double]::IsNaN($First.BorderThickness.Left) | Should -Be -ExpectedValue $false
        $First.BorderThickness.Left | Should -Be -ExpectedValue 0
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

        $Canvas.Children.Count | Should -Be -ExpectedValue 2
    }
}

Describe 'Clear-WpfDesignerSelection' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Select-WpfDesignerElement.ps1"
        . "$PSScriptRoot/../functions/Clear-WpfDesignerSelection.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
    }

    It 'Should remove the resize handle and clear selection state' {
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
}

Describe 'New-WpfDesignerResizeHandle' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
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
}
