Describe 'Resources' -Tag 'Resources' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    BeforeEach {
        $wpfModule = Get-Module -Name WPF
        $wpfModule.SessionState.PSVariable.Set('WPFImplicitStyleTable', @{})
        $wpfModule.SessionState.PSVariable.Set('WPFStyleTable', @{})
    }

    It 'Should register resource entries and apply implicit style from Window resources' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "ResourcesWindow_$id"
        $buttonName = "ResourcesButton_$id"

        $window = Window $windowName {
            Resources {
                LinearGradientBrush 'GrayBlueGradientBrush' {
                    $this.StartPoint = '0,0'
                    $this.EndPoint = '1,1'
                    GradientStop 'DarkGray' 0
                    GradientStop '#CCCCFF' 0.5
                    GradientStop 'DarkGray' 1
                }

                Style Button {
                    Setter Background GrayBlueGradientBrush -Resource
                    Setter Width 80
                    Setter Margin 10
                }
            }

            Button $buttonName {
                $this.Content = 'Demo'
            }
        }

        $contextId = [string] $window.PSObject.Properties['_WPFContextId'].Value
        $button = Reference $buttonName -ContextId $contextId

        $window.Resources.Contains('GrayBlueGradientBrush') | Should -Be $true
        $window.Resources['GrayBlueGradientBrush'] | Should -BeOfType ([System.Windows.Media.LinearGradientBrush])

        $window.Resources.Contains([System.Windows.Controls.Button]) | Should -Be $true
        $implicitButtonStyle = $window.Resources[[System.Windows.Controls.Button]]
        $button.Style | Should -Not -Be $null
        [object]::ReferenceEquals($button.Style, $implicitButtonStyle) | Should -Be $true

        $button.Width | Should -Be 80
        $button.Margin.Left | Should -Be 10
        $button.Margin.Top | Should -Be 10
        $button.Margin.Right | Should -Be 10
        $button.Margin.Bottom | Should -Be 10
    }

    It 'Should keep named styles declared in Resources scoped to the resource dictionary' {
        $id = [guid]::NewGuid().ToString('N')
        $styleName = "ScopedButtonStyle_$id"
        $windowName = "ResourcesWindowScoped_$id"
        $buttonName = "ScopedStyleButton_$id"

        $window = Window $windowName {
            Resources {
                Style $styleName Button {
                    Setter Width 123
                }
            }

            Button $buttonName {
                Resource $styleName Style
            }
        }

        $contextId = [string] $window.PSObject.Properties['_WPFContextId'].Value
        $button = Reference $buttonName -ContextId $contextId

        $window.Resources.Contains($styleName) | Should -Be $true
        $button.Width | Should -Be 123

        $probeButton = [System.Windows.Controls.Button]::new()
        $probeVars = New-WPFVariableList -InputObject $probeButton
        {
            { UseStyle $styleName -ErrorAction Stop }.InvokeWithContext($null, $probeVars) | Out-Null
        } | Should -Throw -ExpectedMessage "*Style '$styleName' is not registered*"
    }

    It 'Should not leak implicit Resources styles into global implicit style registration' {
        $id = [guid]::NewGuid().ToString('N')
        $firstWindowName = "ResourcesScopeA_$id"
        $secondWindowName = "ResourcesScopeB_$id"
        $firstButtonName = "ScopedButtonA_$id"
        $secondButtonName = "ScopedButtonB_$id"

        $firstWindow = Window $firstWindowName {
            Resources {
                Style Button {
                    Setter Width 222
                }
            }

            Button $firstButtonName {}
        }

        $secondWindow = Window $secondWindowName {
            Button $secondButtonName {}
        }

        $firstContextId = [string] $firstWindow.PSObject.Properties['_WPFContextId'].Value
        $secondContextId = [string] $secondWindow.PSObject.Properties['_WPFContextId'].Value

        $firstButton = Reference $firstButtonName -ContextId $firstContextId
        $secondButton = Reference $secondButtonName -ContextId $secondContextId

        $scopedImplicitStyle = $firstWindow.Resources[[System.Windows.Controls.Button]]
        [object]::ReferenceEquals($firstButton.Style, $scopedImplicitStyle) | Should -Be $true
        [object]::ReferenceEquals($secondButton.Style, $scopedImplicitStyle) | Should -Be $false
    }
}
