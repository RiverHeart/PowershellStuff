Describe 'Chrome' -Tag 'Chrome' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Creates a button template shell and applies Chrome setters' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ChromeButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Setter Background '#0A84FF'
            Setter BorderBrush '#086FD5'
            Setter BorderThickness 2
            Setter Padding '14,8,14,8'

            Chrome {
                Setter CornerRadius 6
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.Template | Should -Not -BeNullOrEmpty

        $button.ApplyTemplate() | Out-Null
        $chromeBorder = $button.Template.FindName('ButtonChrome', $button)
        $chromeBorder | Should -Not -BeNullOrEmpty
        $chromeBorder.CornerRadius.TopLeft | Should -Be -ExpectedValue 6
        $chromeBorder.BorderThickness.Left | Should -Be -ExpectedValue 2
    }

    It 'Returns registered adapters via Get-WPFChromeAdapter' {
        $adapters = @(Get-WPFChromeAdapter)
        $adapters | Should -Not -BeNullOrEmpty

        $buttonAdapter = @(Get-WPFChromeAdapter -TargetType ([System.Windows.Controls.Button])) | Select-Object -First 1
        $buttonAdapter | Should -Not -BeNullOrEmpty
        $buttonAdapter.Name | Should -Be -ExpectedValue 'Button'
    }

    It 'Resolves assignable adapters with Get-WPFChromeAdapter -TargetType' {
        $partName = "ButtonBaseChrome_$([guid]::NewGuid().ToString('N'))"

        Register-WPFChromeAdapter `
            -TargetType ([System.Windows.Controls.Primitives.ButtonBase]) `
            -ShellType ([System.Windows.Controls.Border]) `
            -PartName $partName `
            -ShellPropertyMap @{
                Background = [System.Windows.Controls.Border]::BackgroundProperty
            } `
            -ContentPropertyMap @{
                Padding = [System.Windows.FrameworkElement]::MarginProperty
            } `
            -ContentDefaults @{} `
            -Name 'ButtonBase' `
            -Force | Out-Null

        $repeatButtonAdapter = @(Get-WPFChromeAdapter -TargetType ([System.Windows.Controls.Primitives.RepeatButton])) | Select-Object -First 1
        $repeatButtonAdapter | Should -Not -BeNullOrEmpty
        $repeatButtonAdapter.Name | Should -Be -ExpectedValue 'ButtonBase'
    }

    It 'Routes nested Chrome Trigger setters to the generated chrome part' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ChromeTriggerButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Setter Background '#FFFFFF'

            Chrome {
                Setter BorderBrush '#B8C0CC'
                Setter BorderThickness 1
                Setter CornerRadius 6

                Trigger IsEnabled $false {
                    Setter BorderBrush '#2563EB'
                }
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.ApplyTemplate() | Out-Null
        $chromeBorder = $button.Template.FindName('ButtonChrome', $button)
        $chromeBorder.BorderBrush.Color.ToString() | Should -Be -ExpectedValue '#FFB8C0CC'

        $button.IsEnabled = $false
        $chromeBorder.BorderBrush.Color.ToString() | Should -Be -ExpectedValue '#FF2563EB'
    }

    It 'Supports implicit setter shorthand in Chrome and nested Chrome Trigger blocks' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ChromeTriggerShorthandButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            BorderBrush '#B8C0CC'
            BorderThickness 1

            Chrome {
                CornerRadius: 6

                Trigger IsEnabled $false {
                    BorderBrush '#2563EB'
                }
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.ApplyTemplate() | Out-Null
        $chromeBorder = $button.Template.FindName('ButtonChrome', $button)
        $chromeBorder | Should -Not -BeNullOrEmpty

        $chromeBorder.BorderBrush.Color.ToString() | Should -Be -ExpectedValue '#FFB8C0CC'

        $button.IsEnabled = $false
        $chromeBorder.BorderBrush.Color.ToString() | Should -Be -ExpectedValue '#FF2563EB'
    }

    It 'Inherits chrome shell baseline setters from ExtendStyle base style' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ChromeInheritedButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style Button {
            Setter BorderThickness 2
            Setter Padding '14,8,14,8'
            Setter FontSize 14
            Setter Background '#F8FAFC'
            Setter BorderBrush '#8E9AAF'
        }

        Style $styleName Button {
            ExtendStyle Button
            Setter Background '#0A84FF'
            Setter BorderBrush '#086FD5'

            Chrome {
                Setter CornerRadius 6
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $button.ApplyTemplate() | Out-Null
        $chromeBorder = $button.Template.FindName('ButtonChrome', $button)

        $chromeBorder | Should -Not -BeNullOrEmpty
        $chromeBorder.BorderThickness.Left | Should -Be -ExpectedValue 2
    }

    It 'Preserves style dynamic resource setters copied into chrome shell across theme switches' {
        $id = [guid]::NewGuid().ToString('N')
        $light = "Light_$id"
        $dark = "Dark_$id"
        $styleName = "ChromeResourceButton_$id"
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

            Chrome {
                Setter CornerRadius 6
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $window.Content = $button

        Use-WPFTheme -Name $light -Root $window

        $button.ApplyTemplate() | Out-Null
        $chromeBorder = $button.Template.FindName('ButtonChrome', $button)
        $chromeBorder | Should -Not -BeNullOrEmpty

        $button.Background.Color.ToString() | Should -Be -ExpectedValue '#FFFFFFFF'
        $chromeBorder.Background.Color.ToString() | Should -Be -ExpectedValue '#FFFFFFFF'

        Switch-WPFTheme -LightName $light -DarkName $dark -Root $window

        $button.Background.Color.ToString() | Should -Be -ExpectedValue '#FF1E1E1E'
        $chromeBorder.Background.Color.ToString() | Should -Be -ExpectedValue '#FF1E1E1E'
    }

    It 'Preserves style border brush dynamic resource setters copied into chrome shell across theme switches' {
        $id = [guid]::NewGuid().ToString('N')
        $light = "Light_$id"
        $dark = "Dark_$id"
        $styleName = "ChromeResourceBorderButton_$id"
        $window = [System.Windows.Window]::new()
        $button = [System.Windows.Controls.Button]::new()

        Theme $light {
            Brush 'ButtonBorderBrush' '#112233'
        }

        Theme $dark {
            Brush 'ButtonBorderBrush' '#AABBCC'
        }

        Style $styleName Button {
            Setter BorderBrush ButtonBorderBrush -Resource
            Setter BorderThickness 2

            Chrome {
                Setter CornerRadius 6
            }
        }

        $psVars = New-WPFVariableList -InputObject $button
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $window.Content = $button

        Use-WPFTheme -Name $light -Root $window

        $button.ApplyTemplate() | Out-Null
        $chromeBorder = $button.Template.FindName('ButtonChrome', $button)
        $chromeBorder | Should -Not -BeNullOrEmpty

        $button.BorderBrush.Color.ToString() | Should -Be -ExpectedValue '#FF112233'
        $chromeBorder.BorderBrush.Color.ToString() | Should -Be -ExpectedValue '#FF112233'

        Switch-WPFTheme -LightName $light -DarkName $dark -Root $window

        $button.BorderBrush.Color.ToString() | Should -Be -ExpectedValue '#FFAABBCC'
        $chromeBorder.BorderBrush.Color.ToString() | Should -Be -ExpectedValue '#FFAABBCC'
    }

    It 'Uses a registered adapter for non-button target types' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ChromeToggleButton_$id"
        $partName = "ToggleChrome_$id"
        $toggleButton = [System.Windows.Controls.Primitives.ToggleButton]::new()

        Register-WPFChromeAdapter `
            -TargetType ([System.Windows.Controls.Primitives.ToggleButton]) `
            -ShellType ([System.Windows.Controls.Border]) `
            -PartName $partName `
            -ShellPropertyMap @{
                Background = [System.Windows.Controls.Border]::BackgroundProperty
                BorderBrush = [System.Windows.Controls.Border]::BorderBrushProperty
                BorderThickness = [System.Windows.Controls.Border]::BorderThicknessProperty
            } `
            -ContentPropertyMap @{
                Padding = [System.Windows.FrameworkElement]::MarginProperty
                HorizontalContentAlignment = [System.Windows.FrameworkElement]::HorizontalAlignmentProperty
                VerticalContentAlignment = [System.Windows.FrameworkElement]::VerticalAlignmentProperty
            } `
            -ContentDefaults @{
                HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center
                VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center
            } `
            -Force | Out-Null

        $toggleAdapter = @(Get-WPFChromeAdapter -TargetType ([System.Windows.Controls.Primitives.ToggleButton])) | Select-Object -First 1
        $toggleAdapter | Should -Not -BeNullOrEmpty
        $toggleAdapter.PartName | Should -Be -ExpectedValue $partName

        Style $styleName ([System.Windows.Controls.Primitives.ToggleButton]) {
            Setter Background '#F8FAFC'
            Setter BorderBrush '#8E9AAF'
            Setter BorderThickness 2

            Chrome {
                Setter CornerRadius 6
            }
        }

        $psVars = New-WPFVariableList -InputObject $toggleButton
        { UseStyle $styleName }.InvokeWithContext($null, $psVars) | Out-Null

        $toggleButton.ApplyTemplate() | Out-Null
        $chromeBorder = $toggleButton.Template.FindName($partName, $toggleButton)

        $chromeBorder | Should -Not -BeNullOrEmpty
        $chromeBorder.CornerRadius.TopLeft | Should -Be -ExpectedValue 6
        $chromeBorder.BorderThickness.Left | Should -Be -ExpectedValue 2
    }

    It 'Rejects Chrome for unsupported style target types' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ChromeTextBox_$id"

        {
            Style $styleName TextBox {
                Chrome {
                    Setter CornerRadius 6
                }
            } -ErrorAction Stop
        } | Should -Throw -ExpectedMessage "*No Chrome adapter is registered*Registered adapters: Button*"
    }

    It 'Warns about unmapped copied style setters when diagnostics are enabled' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ChromeUnmappedWarning_$id"
        $previousWarningSetting = $env:WPF_CHROME_WARN_UNMAPPED_SETTERS

        try {
            $env:WPF_CHROME_WARN_UNMAPPED_SETTERS = '1'
            $capturedOutput = @(
                (& {
                    Style $styleName Button {
                        Setter FontFamily 'Consolas'
                        Setter Background '#FFFFFF'

                        Chrome {
                            Setter CornerRadius 6
                        }
                    } -WarningAction Continue
                } 3>&1)
            )

            $capturedText = ($capturedOutput | Out-String)
            $capturedText | Should -Match 'FontFamily'
            $capturedText | Should -Match 'not mapped into adapter'
        } finally {
            if ($null -eq $previousWarningSetting) {
                Remove-Item Env:WPF_CHROME_WARN_UNMAPPED_SETTERS -ErrorAction SilentlyContinue
            } else {
                $env:WPF_CHROME_WARN_UNMAPPED_SETTERS = $previousWarningSetting
            }
        }
    }
}
