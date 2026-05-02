Describe 'Theme' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should register and apply a named theme' {
        $id = [guid]::NewGuid().ToString('N')
        $light = "Light_$id"
        $dark = "Dark_$id"
        $window = [System.Windows.Window]::new()

        Theme $light {
            Brush 'WindowBackground' '#FFFFFF'
        }

        Theme $dark {
            Brush 'WindowBackground' '#1E1E1E'
        }

        $psVars = New-WPFVariableList -InputObject $window
        { Resource Background WindowBackground }.InvokeWithContext($null, $psVars) | Out-Null

        Use-WPFTheme -Name $light -Root $window
        $window.Background.Color.ToString() | Should -Be -ExpectedValue '#FFFFFFFF'

        Switch-WPFTheme -LightName $light -DarkName $dark -Root $window
        $window.Background.Color.ToString() | Should -Be -ExpectedValue '#FF1E1E1E'
    }

    It 'Should update styled controls when the active theme changes' {
        $id = [guid]::NewGuid().ToString('N')
        $light = "Light_$id"
        $dark = "Dark_$id"
        $styleName = "Button_$id"
        $window = [System.Windows.Window]::new()
        $button = [System.Windows.Controls.Button]::new()

        Theme $light {
            Brush 'ButtonBackground' '#FFFFFF'
        }

        Theme $dark {
            Brush 'ButtonBackground' '#1E1E1E'
        }

        Style $styleName Button {
            Setter Background ButtonBackground -Resource
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $window.Content = $button

        Use-WPFTheme -Name $light -Root $window
        $button.Background.Color.ToString() | Should -Be -ExpectedValue '#FFFFFFFF'

        Switch-WPFTheme -LightName $light -DarkName $dark -Root $window
        $button.Background.Color.ToString() | Should -Be -ExpectedValue '#FF1E1E1E'
    }

    It 'Should auto-apply implicit target-type styles' {
        $id = [guid]::NewGuid().ToString('N')
        $light = "Light_$id"

        Theme $light {
            Brush 'ButtonBackground' '#123456'
        }

        Style Button {
            Setter Background ButtonBackground -Resource
        }

        $window = Window "Window_$id" {
            Button "Button_$id" {}
        }

        Use-WPFTheme -Name $light -Root $window

        $button = Reference "Button_$id"
        $button.Background.Color.ToString() | Should -Be -ExpectedValue '#FF123456'
    }

    It 'Should convert string setter values to dependency property types' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "MarginButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Setter Margin '0,8,0,0'
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.Margin.Left | Should -Be -ExpectedValue 0
        $button.Margin.Top | Should -Be -ExpectedValue 8
        $button.Margin.Right | Should -Be -ExpectedValue 0
        $button.Margin.Bottom | Should -Be -ExpectedValue 0
    }
}
