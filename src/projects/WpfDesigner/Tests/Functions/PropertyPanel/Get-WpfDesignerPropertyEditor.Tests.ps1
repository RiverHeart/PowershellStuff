Describe 'Get-WpfDesignerPropertyEditor' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WpfDesigner.psm1" -Force
    }

    It 'Should build a two-way bound TextBox for a Text property' {
        $Target = [System.Windows.Controls.TextBlock]::new()
        $Descriptor = [pscustomobject] @{ Name = 'Text'; PropertyType = [string]; EditorKind = 'Text' }

        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target

        $Editor.Input | Should -BeOfType [System.Windows.Controls.TextBox]

        $Editor.Input.Text = 'Updated'
        $BindingExpression = [System.Windows.Data.BindingOperations]::GetBindingExpression($Editor.Input, [System.Windows.Controls.TextBox]::TextProperty)
        $BindingExpression.UpdateSource()

        $Target.Text | Should -Be -ExpectedValue 'Updated'
    }

    It 'Should build a read-only TextBox for uneditable Text content' {
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Content = [System.Windows.Controls.StackPanel]::new()
        $Descriptor = [pscustomobject] @{
            Name         = 'Content'
            PropertyType = [object]
            EditorKind   = 'Text'
            IsReadOnly   = $true
        }

        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target
        $Binding = [System.Windows.Data.BindingOperations]::GetBinding($Editor.Input, [System.Windows.Controls.TextBox]::TextProperty)

        $Editor.Input.IsReadOnly | Should -BeTrue
        $Binding.Mode | Should -Be ([System.Windows.Data.BindingMode]::OneWay)
    }

    It 'Should build a two-way bound TextBox for a Number property' {
        $Target = [System.Windows.Controls.TextBlock]::new()
        $Descriptor = [pscustomobject] @{ Name = 'Width'; PropertyType = [double]; EditorKind = 'Number' }

        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target

        $Editor.Input | Should -BeOfType [System.Windows.Controls.TextBox]

        $Editor.Input.Text = '150'
        $BindingExpression = [System.Windows.Data.BindingOperations]::GetBindingExpression($Editor.Input, [System.Windows.Controls.TextBox]::TextProperty)
        $BindingExpression.UpdateSource()

        $Target.Width | Should -Be -ExpectedValue 150
    }

    It 'Should display and accept None for an unbounded Number property' {
        $Target = [System.Windows.Controls.TextBlock]::new()
        $Descriptor = [pscustomobject] @{ Name = 'MaxWidth'; PropertyType = [double]; EditorKind = 'Number' }

        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target

        $Editor.Input.Text | Should -Be -ExpectedValue 'None'

        $Editor.Input.Text = '240'
        $BindingExpression = [System.Windows.Data.BindingOperations]::GetBindingExpression($Editor.Input, [System.Windows.Controls.TextBox]::TextProperty)
        $BindingExpression.UpdateSource()
        $Target.MaxWidth | Should -Be -ExpectedValue 240

        $Editor.Input.Text = 'None'
        $BindingExpression.UpdateSource()
        [double]::IsPositiveInfinity($Target.MaxWidth) | Should -BeTrue
    }

    It 'Should build a two-way bound CheckBox for a Bool property' {
        $Target = [System.Windows.Controls.TextBlock]::new()
        $Descriptor = [pscustomobject] @{ Name = 'IsEnabled'; PropertyType = [bool]; EditorKind = 'Bool' }

        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target

        $Editor.Input | Should -BeOfType [System.Windows.Controls.CheckBox]
        $Editor.Input.Content | Should -Be -ExpectedValue 'IsEnabled'
        $Editor.Elements | Should -HaveCount 1
        $Editor.Elements[0] | Should -Be $Editor.Input

        $Editor.Input.IsChecked = $false

        $Target.IsEnabled | Should -Be -ExpectedValue $false
    }

    It 'Should build a two-way bound ComboBox for an Enum property' {
        $Target = [System.Windows.Controls.TextBlock]::new()
        $Descriptor = [pscustomobject] @{ Name = 'TextWrapping'; PropertyType = [System.Windows.TextWrapping]; EditorKind = 'Enum' }

        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target

        $Editor.Input | Should -BeOfType [System.Windows.Controls.ComboBox]
        $Editor.Input.ItemTemplate | Should -BeNullOrEmpty
        $Editor.Input.ItemsSource | Should -Contain ([System.Windows.TextWrapping]::WrapWithOverflow)
        $Editor.Input.SelectedItem | Should -Be ([System.Windows.TextWrapping]::NoWrap)

        $Editor.Input.SelectedItem = [System.Windows.TextWrapping]::WrapWithOverflow

        $Target.TextWrapping | Should -Be -ExpectedValue ([System.Windows.TextWrapping]::WrapWithOverflow)
    }

    It 'Should label the row with the property name' {
        $Target = [System.Windows.Controls.TextBlock]::new()
        $Descriptor = [pscustomobject] @{ Name = 'Text'; PropertyType = [string]; EditorKind = 'Text' }

        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target

        $Editor.Label.Text | Should -Be -ExpectedValue 'Text'
    }
}
