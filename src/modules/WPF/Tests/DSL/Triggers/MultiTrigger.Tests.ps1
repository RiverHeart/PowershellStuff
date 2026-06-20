Describe 'MultiTrigger' -Tag 'MultiTrigger' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    It 'Should apply style multi trigger setters when all conditions are met' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "MultiTriggerButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Setter Opacity 1.0

            MultiTrigger @(
                @{ Property = 'IsEnabled'; Value = $false }
                @{ Property = 'IsDefault'; Value = $true }
            ) {
                Setter Opacity 0.3
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.Opacity | Should -Be -ExpectedValue 1.0

        $button.IsDefault = $true
        $button.Opacity | Should -Be -ExpectedValue 1.0

        $button.IsEnabled = $false
        $button.Opacity | Should -Be -ExpectedValue 0.3
    }

    It 'Should add control template multi triggers and support source/target names' {
        $template = [System.Windows.Controls.ControlTemplate]::new([System.Windows.Controls.Button])
        $psVars = New-WPFVariableList -InputObject $template

        {
            MultiTrigger @(
                @{ Property = 'IsEnabled'; Value = $false; SourceName = 'TemplateRoot' }
            ) {
                Setter Opacity 0.5 -Target 'TemplateRoot'
            }
        }.InvokeWithContext($null, $psVars) | Out-Null

        $template.Triggers.Count | Should -Be -ExpectedValue 1

        $trigger = [System.Windows.MultiTrigger] $template.Triggers[0]
        $trigger.Conditions.Count | Should -Be -ExpectedValue 1
        $trigger.Conditions[0].Property.Name | Should -Be -ExpectedValue 'IsEnabled'
        $trigger.Conditions[0].Value | Should -Be -ExpectedValue $false
        $trigger.Conditions[0].SourceName | Should -Be -ExpectedValue 'TemplateRoot'
        $trigger.Setters.Count | Should -Be -ExpectedValue 1
        $trigger.Setters[0].TargetName | Should -Be -ExpectedValue 'TemplateRoot'
    }

    It 'Should reject multi trigger usage outside style or template contexts' {
        $button = [System.Windows.Controls.Button]::new()
        $psVars = New-WPFVariableList -InputObject $button

        {
            { MultiTrigger @(@{ Property = 'IsEnabled'; Value = $false }) { Setter Opacity 0.5 } -ErrorAction Stop }.InvokeWithContext($null, $psVars) | Out-Null
        } | Should -Throw
    }
}
