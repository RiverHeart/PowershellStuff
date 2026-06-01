Describe 'DataTrigger' -Tag 'DataTrigger' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should apply style data trigger setters when condition is met' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "DataTriggerButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Setter Opacity 1.0

            DataTrigger 'IsEnabled' $false -Self {
                Setter Opacity 0.35
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.Opacity | Should -Be -ExpectedValue 1.0

        $button.IsEnabled = $false
        $button.Opacity | Should -Be -ExpectedValue 0.35
    }

    It 'Should add control template data triggers and support setter target names' {
        $template = [System.Windows.Controls.ControlTemplate]::new([System.Windows.Controls.Button])
        $binding = Binding 'IsEnabled' -TemplatedParent
        $psVars = New-WPFVariableList -InputObject $template

        {
            DataTrigger $binding $false {
                Setter Opacity 0.5 -Target 'TemplateRoot'
            }
        }.InvokeWithContext($null, $psVars) | Out-Null

        $template.Triggers.Count | Should -Be -ExpectedValue 1

        $trigger = [System.Windows.DataTrigger] $template.Triggers[0]
        $trigger.Binding.Path.Path | Should -Be -ExpectedValue 'IsEnabled'
        $trigger.Value | Should -Be -ExpectedValue $false
        $trigger.Setters.Count | Should -Be -ExpectedValue 1
        $trigger.Setters[0].TargetName | Should -Be -ExpectedValue 'TemplateRoot'
    }

    It 'Should reject data trigger usage outside style or template contexts' {
        $button = [System.Windows.Controls.Button]::new()
        $psVars = New-WPFVariableList -InputObject $button

        {
            { DataTrigger 'IsEnabled' $false -Self { Setter Opacity 0.5 } -ErrorAction Stop }.InvokeWithContext($null, $psVars) | Out-Null
        } | Should -Throw
    }
}
