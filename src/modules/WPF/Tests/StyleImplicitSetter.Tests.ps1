Describe 'Style implicit setter syntax' -Tag 'Style' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Applies implicit property commands as style setters' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ImplicitSetterButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            FontSize 16
            Margin '2,4,6,8'
            FocusVisualStyle $null
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.FontSize | Should -Be -ExpectedValue 16
        $button.Margin.Top | Should -Be -ExpectedValue 4
        $button.Margin.Left | Should -Be -ExpectedValue 2
        $button.FocusVisualStyle | Should -BeNullOrEmpty
    }

    It 'Keeps existing style DSL commands working with implicit setters' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ImplicitSetterTriggerButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Opacity 1.0

            Trigger IsEnabled $false {
                Setter Opacity 0.35
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.Opacity | Should -Be -ExpectedValue 1.0
        $button.IsEnabled = $false
        $button.Opacity | Should -Be -ExpectedValue 0.35
    }

    It 'Forwards shorthand flags to Setter (for example -Resource)' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ImplicitSetterResourceButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Background ButtonBackground -Resource
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.Style | Should -Not -BeNullOrEmpty
        $button.Style.Setters.Count | Should -Be -ExpectedValue 1
        $button.Style.Setters[0].Value | Should -BeOfType ([System.Windows.DynamicResourceExtension])
        $button.Style.Setters[0].Value.ResourceKey | Should -Be -ExpectedValue 'ButtonBackground'
    }

    It 'Supports explicit property delimiter syntax with a trailing colon' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ImplicitSetterDelimiterButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            BorderBrush: '#010203'
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.BorderBrush | Should -Not -BeNullOrEmpty
        $button.BorderBrush.Color.ToString() | Should -Be -ExpectedValue '#FF010203'
    }

    It 'Uses explicit delimiter to force property interpretation when names collide with commands' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ImplicitSetterCollisionButton_$id"

        {
            Style $styleName Button {
                Border: 'Transparent'
            } -ErrorAction Stop
        } | Should -Throw -ExpectedMessage "*Property 'Border' is not a dependency property on type 'System.Windows.Controls.Button'.*"
    }
}
