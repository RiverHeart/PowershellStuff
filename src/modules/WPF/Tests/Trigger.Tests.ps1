Describe 'Trigger' -Tag 'Trigger' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should apply style trigger setters when the trigger condition is met' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "TriggerButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Setter Opacity 1.0

            Trigger IsEnabled $false {
                Setter Opacity 0.4
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.Opacity | Should -Be -ExpectedValue 1.0

        $button.IsEnabled = $false
        $button.Opacity | Should -Be -ExpectedValue 0.4
    }

    It 'Should support implicit setter shorthand inside Trigger blocks' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "TriggerShorthandButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Opacity: 1.0

            Trigger IsEnabled $false {
                Opacity: 0.4
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.Opacity | Should -Be -ExpectedValue 1.0

        $button.IsEnabled = $false
        $button.Opacity | Should -Be -ExpectedValue 0.4
    }

    It 'Should add control template triggers and support setter target names' {
        $template = [System.Windows.Controls.ControlTemplate]::new([System.Windows.Controls.Button])
        $psVars = New-WPFVariableList -InputObject $template

        {
            Trigger IsEnabled $false -SourceName 'TemplateRoot' {
                Setter Opacity 0.5 -Target 'TemplateRoot'
            }
        }.InvokeWithContext($null, $psVars) | Out-Null

        $template.Triggers.Count | Should -Be -ExpectedValue 1

        $trigger = $template.Triggers[0]
        $trigger.Property.Name | Should -Be -ExpectedValue 'IsEnabled'
        $trigger.Value | Should -Be -ExpectedValue $false
        $trigger.SourceName | Should -Be -ExpectedValue 'TemplateRoot'
        $trigger.Setters.Count | Should -Be -ExpectedValue 1
        $trigger.Setters[0].TargetName | Should -Be -ExpectedValue 'TemplateRoot'
    }

    It 'Should reject trigger usage outside style or template contexts' {
        $button = [System.Windows.Controls.Button]::new()
        $psVars = New-WPFVariableList -InputObject $button

        {
            { Trigger IsEnabled $false { Setter Opacity 0.5 } -ErrorAction Stop }.InvokeWithContext($null, $psVars) | Out-Null
        } | Should -Throw
    }

}
