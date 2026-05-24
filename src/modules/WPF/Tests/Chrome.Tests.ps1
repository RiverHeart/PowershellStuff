Describe 'Chrome' -Tag 'Chrome' {
    BeforeAll {
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

    It 'Routes Trigger -Scope Chrome setters to the generated chrome part' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ChromeTriggerButton_$id"
        $button = [System.Windows.Controls.Button]::new()

        Style $styleName Button {
            Setter Background '#FFFFFF'

            Chrome {
                Setter BorderBrush '#B8C0CC'
                Setter BorderThickness 1
                Setter CornerRadius 6
            }

            Trigger IsEnabled $false -Scope Chrome {
                Setter BorderBrush '#2563EB'
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

    It 'Rejects Chrome for unsupported style target types' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ChromeTextBox_$id"

        {
            Style $styleName TextBox {
                Chrome {
                    Setter CornerRadius 6
                }
            } -ErrorAction Stop
        } | Should -Throw
    }
}
