Describe 'Theme' -Tag 'Theme' {
    BeforeDiscovery {
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

    It 'Should support implicit Brush shorthand inside Theme blocks' {
        $id = [guid]::NewGuid().ToString('N')
        $themeName = "Shorthand_$id"
        $window = [System.Windows.Window]::new()

        Theme $themeName {
            WindowBackground '#ABCDEF'
        }

        $psVars = New-WPFVariableList -InputObject $window
        { Resource Background WindowBackground }.InvokeWithContext($null, $psVars) | Out-Null

        Use-WPFTheme -Name $themeName -Root $window
        $window.Background.Color.ToString() | Should -Be -ExpectedValue '#FFABCDEF'
    }

    It 'Should allow mixing implicit Brush shorthand and explicit Brush calls' {
        $id = [guid]::NewGuid().ToString('N')
        $themeName = "MixedTheme_$id"
        $window = [System.Windows.Window]::new()
        $button = [System.Windows.Controls.Button]::new()

        Theme $themeName {
            WindowBackground '#EEEEEE'
            Brush 'ButtonBackground' '#123456'
        }

        $window.Content = $button

        $windowVars = New-WPFVariableList -InputObject $window
        { Resource Background WindowBackground }.InvokeWithContext($null, $windowVars) | Out-Null

        $buttonVars = New-WPFVariableList -InputObject $button
        { Resource Background ButtonBackground }.InvokeWithContext($null, $buttonVars) | Out-Null

        Use-WPFTheme -Name $themeName -Root $window
        $window.Background.Color.ToString() | Should -Be -ExpectedValue '#FFEEEEEE'
        $button.Background.Color.ToString() | Should -Be -ExpectedValue '#FF123456'
    }

    It 'Should support explicit key delimiter syntax with a trailing colon' {
        $id = [guid]::NewGuid().ToString('N')
        $themeName = "ThemeDelimiter_$id"
        $window = [System.Windows.Window]::new()

        Theme $themeName {
            WindowBackground: '#112233'
        }

        $psVars = New-WPFVariableList -InputObject $window
        { Resource Background WindowBackground }.InvokeWithContext($null, $psVars) | Out-Null

        Use-WPFTheme -Name $themeName -Root $window
        $window.Background.Color.ToString() | Should -Be -ExpectedValue '#FF112233'
    }

    It 'Uses explicit delimiter to force key interpretation for names that collide with keywords or commands' {
        $id = [guid]::NewGuid().ToString('N')
        $themeName = "ThemeCollision_$id"
        $window = [System.Windows.Window]::new()
        $secondWindow = [System.Windows.Window]::new()

        Theme $themeName {
            Brush: '#445566'
            Get-Date: '#223344'
        }

        $psVars = New-WPFVariableList -InputObject $window
        { Resource Background Brush }.InvokeWithContext($null, $psVars) | Out-Null

        $secondVars = New-WPFVariableList -InputObject $secondWindow
        { Resource Background 'Get-Date' }.InvokeWithContext($null, $secondVars) | Out-Null

        Use-WPFTheme -Name $themeName -Root $window
        Use-WPFTheme -Name $themeName -Root $secondWindow
        $window.Background.Color.ToString() | Should -Be -ExpectedValue '#FF445566'
        $secondWindow.Background.Color.ToString() | Should -Be -ExpectedValue '#FF223344'
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
