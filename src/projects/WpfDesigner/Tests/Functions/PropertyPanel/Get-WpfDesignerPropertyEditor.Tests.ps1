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
        $Descriptor = [pscustomobject] @{ Name = 'HorizontalAlignment'; PropertyType = [System.Windows.HorizontalAlignment]; EditorKind = 'Enum' }

        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target

        $Editor.Input | Should -BeOfType [System.Windows.Controls.ComboBox]
        $Editor.Input.ItemsSource | Should -Contain ([System.Windows.HorizontalAlignment]::Right)
        $Editor.Input.SelectedItem | Should -Be ([System.Windows.HorizontalAlignment]::Stretch)

        $Editor.Input.SelectedItem = [System.Windows.HorizontalAlignment]::Right

        $Target.HorizontalAlignment | Should -Be -ExpectedValue ([System.Windows.HorizontalAlignment]::Right)
    }

    It 'Should label the row with the property name' {
        $Target = [System.Windows.Controls.TextBlock]::new()
        $Descriptor = [pscustomobject] @{ Name = 'Text'; PropertyType = [string]; EditorKind = 'Text' }

        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target

        $Editor.Label.Text | Should -Be -ExpectedValue 'Text'
    }
}
