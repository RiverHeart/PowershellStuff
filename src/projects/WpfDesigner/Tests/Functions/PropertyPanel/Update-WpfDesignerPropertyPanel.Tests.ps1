Describe 'Update-WpfDesignerPropertyPanel' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WpfDesigner.psm1" -Force
    }

    It 'Should populate editor elements for each property descriptor' {
        $Panel = [System.Windows.Controls.StackPanel]::new()
        $Target = [System.Windows.Controls.TextBlock]::new()
        $State = @{ SelectedElement = $Target }

        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $Descriptors = @(Get-WpfDesignerPropertyDescriptor -InputObject $Target)
        $Categories = @($Descriptors | Group-Object Category)
        $ExpectedRowCount = ($Descriptors | ForEach-Object { if ($_.EditorKind -eq 'Bool') { 1 } else { 2 } } | Measure-Object -Sum).Sum
        $EditorElements = @($Panel.Children | ForEach-Object { $_.Content.Children })
        $Panel.Children.Count | Should -Be -ExpectedValue $Categories.Count
        @($Panel.Children | Where-Object { $_ -isnot [System.Windows.Controls.Expander] -or -not $_.IsExpanded }) | Should -HaveCount 0
        @($Panel.Children.Header) | Should -Be $Categories.Name
        $EditorElements | Should -HaveCount $ExpectedRowCount
        $BoolDescriptor = $Descriptors | Where-Object EditorKind -eq 'Bool' | Select-Object -First 1
        $BoolEditor = $EditorElements | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.Content -eq $BoolDescriptor.Name }
        $BoolEditor | Should -HaveCount 1
    }

    It 'Should populate rows from an associated property target' {
        $Panel = [System.Windows.Controls.StackPanel]::new()
        $Frame = [System.Windows.Controls.Border]::new()
        $Window = [System.Windows.Window]::new()
        $Frame | Add-Member -NotePropertyName '_WPFDesignerPropertyTarget' -NotePropertyValue $Window
        $State = @{ SelectedElement = $Frame }

        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $Descriptors = @(Get-WpfDesignerPropertyDescriptor -InputObject $Window)
        $Categories = @($Descriptors | Group-Object Category)
        $EditorElements = @($Panel.Children | ForEach-Object { $_.Content.Children })
        $Panel.Children.Count | Should -Be -ExpectedValue $Categories.Count
        @($EditorElements | Where-Object DataContext -eq $Window).Count | Should -BeGreaterThan 0
    }

    It 'Should replace rather than append rows when selection changes' {
        $Panel = [System.Windows.Controls.StackPanel]::new()
        $State = @{ SelectedElement = [System.Windows.Controls.TextBlock]::new() }
        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $State.SelectedElement = [System.Windows.Controls.Label]::new()
        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State

        $Descriptors = @(Get-WpfDesignerPropertyDescriptor -InputObject $State.SelectedElement)
        $Categories = @($Descriptors | Group-Object Category)
        $Panel.Children.Count | Should -Be -ExpectedValue $Categories.Count
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
