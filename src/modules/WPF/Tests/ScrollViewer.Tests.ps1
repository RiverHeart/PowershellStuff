Describe 'ScrollViewer' -Tag 'ScrollViewer' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -ScrollViewer "Viewer_$Id" {
                Label "Child_$Id" {}
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }

    It 'Should support factory mode inside a template with PART_ContentHost' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "TextBoxTemplate_$Id"
        $TextBox = [System.Windows.Controls.TextBox]::new()

        Style $StyleName TextBox {
            Template {
                Border 'InputChrome' {
                    ScrollViewer 'PART_ContentHost' {
                        Setter Margin '2,2,2,2'
                    }
                }
            }
        }

        $Vars = New-WPFVariableList -InputObject $TextBox
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $TextBox.ApplyTemplate() | Out-Null
        $ContentHost = $TextBox.Template.FindName('PART_ContentHost', $TextBox)

        $ContentHost | Should -Not -BeNullOrEmpty
        $ContentHost.GetType().FullName | Should -Be -ExpectedValue 'System.Windows.Controls.ScrollViewer'
    }

    It 'Should support implicit setter shorthand in Border and ContentPresenter template factory blocks' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "ButtonTemplateShorthand_$Id"
        $Button = [System.Windows.Controls.Button]::new()

        Style $StyleName Button {
            Template {
                Border 'TemplateBorder' {
                    Padding '3,4,5,6'

                    ContentPresenter {
                        HorizontalAlignment ([System.Windows.HorizontalAlignment]::Stretch)
                        VerticalAlignment ([System.Windows.VerticalAlignment]::Stretch)
                        SnapsToDevicePixels $true
                    }
                }
            }
        }

        $Vars = New-WPFVariableList -InputObject $Button
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $Button.ApplyTemplate() | Out-Null
        $TemplateBorder = $Button.Template.FindName('TemplateBorder', $Button)

        $TemplateBorder | Should -Not -BeNullOrEmpty
        $TemplateBorder.Padding.Left | Should -Be -ExpectedValue 3
        $TemplateBorder.Padding.Top | Should -Be -ExpectedValue 4
        $TemplateBorder.Padding.Right | Should -Be -ExpectedValue 5
        $TemplateBorder.Padding.Bottom | Should -Be -ExpectedValue 6
    }

    It 'Should forward -Resource in template factory shorthand statements' {
        $Id = [guid]::NewGuid().ToString('N')
        $ThemeName = "FactoryResourceTheme_$Id"
        $StyleName = "FactoryResourceStyle_$Id"
        $Window = [System.Windows.Window]::new()
        $Button = [System.Windows.Controls.Button]::new()

        Theme $ThemeName {
            ButtonBackground '#223344'
        }

        Style $StyleName Button {
            Template {
                Border 'TemplateBorder' {
                    Background ButtonBackground -Resource
                }
            }
        }

        $Vars = New-WPFVariableList -InputObject $Button
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $Window.Content = $Button
        Use-WPFTheme -Name $ThemeName -Root $Window

        $Button.ApplyTemplate() | Out-Null
        $TemplateBorder = $Button.Template.FindName('TemplateBorder', $Button)

        $TemplateBorder | Should -Not -BeNullOrEmpty
        $TemplateBorder.Background.Color.ToString() | Should -Be -ExpectedValue '#FF223344'
    }

    It 'Should support explicit property delimiter syntax in template factory statements' {
        $Id = [guid]::NewGuid().ToString('N')
        $ThemeName = "FactoryDelimiterTheme_$Id"
        $StyleName = "FactoryDelimiterStyle_$Id"
        $Window = [System.Windows.Window]::new()
        $Button = [System.Windows.Controls.Button]::new()

        Theme $ThemeName {
            ButtonBackground '#334455'
        }

        Style $StyleName Button {
            Template {
                Border 'TemplateBorder' {
                    Background: ButtonBackground -Resource
                }
            }
        }

        $Vars = New-WPFVariableList -InputObject $Button
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $Window.Content = $Button
        Use-WPFTheme -Name $ThemeName -Root $Window

        $Button.ApplyTemplate() | Out-Null
        $TemplateBorder = $Button.Template.FindName('TemplateBorder', $Button)

        $TemplateBorder | Should -Not -BeNullOrEmpty
        $TemplateBorder.Background.Color.ToString() | Should -Be -ExpectedValue '#FF334455'
    }
}
