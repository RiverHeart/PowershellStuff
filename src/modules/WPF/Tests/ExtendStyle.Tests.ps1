Describe 'ExtendStyle' -Tag 'ExtendStyle' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Inherits from implicit style by target type' {
        $id = [guid]::NewGuid().ToString('N')
        $baseName = "BaseButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style Button {
            Setter FontSize 15
            Setter Margin '1,2,3,4'
        }

        Style $baseName Button {
            ExtendStyle Button
            Setter Background '#0A84FF'
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $baseName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.FontSize | Should -Be -ExpectedValue 15
        $button.Margin.Top | Should -Be -ExpectedValue 2
        $button.Background.Color.ToString() | Should -Be -ExpectedValue '#FF0A84FF'
    }

    It 'Inherits from a named base style by key' {
        $id = [guid]::NewGuid().ToString('N')
        $baseName = "ButtonBase_$id"
        $childName = "ButtonChild_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $baseName Button {
            Setter Padding '7,9,7,9'
            Setter FontSize 13
        }

        Style $childName Button {
            ExtendStyle $baseName
            Setter Opacity 0.8
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $childName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.Padding.Top | Should -Be -ExpectedValue 9
        $button.FontSize | Should -Be -ExpectedValue 13
        $button.Opacity | Should -Be -ExpectedValue 0.8
    }

    It 'Throws when implicit base style does not exist for requested target type' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "NeedsMissingBase_$id"

        {
            Style $styleName Button {
                ExtendStyle TextBox
            } -ErrorAction Stop
        } | Should -Throw
    }
}
