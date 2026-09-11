Describe 'Update-WpfDesignerPropertyPanel' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerEnterCommit.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerEditorKind.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerPropertyDescriptor.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerPropertyEditor.ps1"
        . "$PSScriptRoot/../functions/Update-WpfDesignerPropertyPanel.ps1"
    }

    It 'Should populate one Label + input row per property descriptor' {
        $Panel = [System.Windows.Controls.StackPanel]::new()
        $Target = [System.Windows.Controls.TextBlock]::new()
        $State = @{ SelectedElement = $Target }

        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $ExpectedRowCount = @(Get-WpfDesignerPropertyDescriptor -InputObject $Target).Count * 2
        $Panel.Children.Count | Should -Be -ExpectedValue $ExpectedRowCount
    }

    It 'Should populate rows from an associated property target' {
        $Panel = [System.Windows.Controls.StackPanel]::new()
        $Frame = [System.Windows.Controls.Border]::new()
        $Window = [System.Windows.Window]::new()
        $Frame | Add-Member -NotePropertyName '_WPFDesignerPropertyTarget' -NotePropertyValue $Window
        $State = @{ SelectedElement = $Frame }

        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $ExpectedRowCount = @(Get-WpfDesignerPropertyDescriptor -InputObject $Window).Count * 2
        $Panel.Children.Count | Should -Be -ExpectedValue $ExpectedRowCount
        $Panel.Children[1].DataContext | Should -Be -ExpectedValue $Window
    }

    It 'Should replace rather than append rows when selection changes' {
        $Panel = [System.Windows.Controls.StackPanel]::new()
        $State = @{ SelectedElement = [System.Windows.Controls.TextBlock]::new() }
        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $State.SelectedElement = [System.Windows.Controls.Label]::new()
        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $ExpectedRowCount = @(Get-WpfDesignerPropertyDescriptor -InputObject $State.SelectedElement).Count * 2
        $Panel.Children.Count | Should -Be -ExpectedValue $ExpectedRowCount
    }

    It 'Should empty the panel when selection is cleared' {
        $Panel = [System.Windows.Controls.StackPanel]::new()
        $State = @{ SelectedElement = [System.Windows.Controls.TextBlock]::new() }
        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $State.SelectedElement = $null
        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $Panel.Children.Count | Should -Be -ExpectedValue 0
    }
}
