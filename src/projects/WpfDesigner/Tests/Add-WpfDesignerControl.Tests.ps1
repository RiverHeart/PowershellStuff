Describe 'Add-WpfDesignerControl container-aware placement' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerContainerMarker.ps1"
        . "$PSScriptRoot/../functions/Test-WpfDesignerContainer.ps1"
        . "$PSScriptRoot/../functions/Test-WpfDesignerContainerCapacity.ps1"
        . "$PSScriptRoot/../functions/Add-WpfDesignerControl.ps1"
        . "$PSScriptRoot/../functions/Add-WpfDesignerLabel.ps1"
        . "$PSScriptRoot/../functions/Add-WpfDesignerStackPanel.ps1"
        . "$PSScriptRoot/../functions/Select-WpfDesignerElement.ps1"
        . "$PSScriptRoot/../functions/Clear-WpfDesignerSelection.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerResizeHandle.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerResizeHandlePosition.ps1"
        . "$PSScriptRoot/../functions/New-WpfDesignerSelectionOutline.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerSelectionOutlinePosition.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerCanvasRelativePosition.ps1"
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

    It 'Should nest the new element inside the Window frame Border when selected and empty' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Frame = [System.Windows.Controls.Border]::new()
        Add-WpfDesignerContainerMarker -InputObject $Frame
        $Canvas.Children.Add($Frame) | Out-Null
        $State = @{ SelectedElement = $Frame }

        $NewLabel = Add-WpfDesignerLabel -Canvas $Canvas -State $State

        $Frame.Child | Should -Be -ExpectedValue $NewLabel
    }

    It 'Should fall back to floating when the selected Border container already has a child' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Frame = [System.Windows.Controls.Border]::new()
        Add-WpfDesignerContainerMarker -InputObject $Frame
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

        Test-WpfDesignerContainer -InputObject $StackPanel | Should -Be -ExpectedValue $true
    }
}
