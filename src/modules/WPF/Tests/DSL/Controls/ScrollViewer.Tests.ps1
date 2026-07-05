Describe 'ScrollViewer' -Tag 'ScrollViewer' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        {
            -ScrollViewer "Viewer_$Id" {
                Label "Child_$Id" {}
            }
        }.Invoke() | Out-Null

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
                        Setter Margin 2
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
                    Padding: 3, 4, 5, 6

                    ContentPresenter {
                        HorizontalAlignment: ([System.Windows.HorizontalAlignment]::Stretch)
                        VerticalAlignment: ([System.Windows.VerticalAlignment]::Stretch)
                        SnapsToDevicePixels: $true
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
            ButtonBackground: '#223344'
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
        $TemplateBorder.Background.Color.ToString() | Should -Be -ExpectedValue '#FF223344'
    }

    It 'Should support explicit property delimiter syntax in template factory statements' {
        $Id = [guid]::NewGuid().ToString('N')
        $ThemeName = "FactoryDelimiterTheme_$Id"
        $StyleName = "FactoryDelimiterStyle_$Id"
        $Window = [System.Windows.Window]::new()
        $Button = [System.Windows.Controls.Button]::new()

        Theme $ThemeName {
            ButtonBackground: '#334455'
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

    It 'Should support nested Grid, Rectangle, DockPanel, and named ContentPresenter in template blocks' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "AnimatedShapeTemplate_$Id"
        $Button = [System.Windows.Controls.Button]::new()

        Style $StyleName Button {
            Template {
                Grid {
                    Rectangle 'OuterRect' {
                        Fill: 'Transparent'
                        StrokeThickness: 5
                    }

                    Rectangle 'InnerRect' {
                        Fill: 'DarkGray'
                        Stroke: 'Transparent'
                    }

                    DockPanel 'ContentPresenterPanel' {
                        ContentPresenter 'ContentPresenter' {
                            Margin: 20
                            Content: 'Template content'
                        }
                    }
                }
            }
        }

        $Vars = New-WPFVariableList -InputObject $Button
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $Button.ApplyTemplate() | Out-Null
        $OuterRect = $Button.Template.FindName('OuterRect', $Button)
        $InnerRect = $Button.Template.FindName('InnerRect', $Button)
        $PresenterPanel = $Button.Template.FindName('ContentPresenterPanel', $Button)
        $Presenter = $Button.Template.FindName('ContentPresenter', $Button)

        $OuterRect | Should -Not -Be $null
        $OuterRect.GetType().FullName | Should -Be -ExpectedValue 'System.Windows.Shapes.Rectangle'
        $OuterRect.StrokeThickness | Should -Be -ExpectedValue 5

        $InnerRect | Should -Not -Be $null
        $InnerRect.GetType().FullName | Should -Be -ExpectedValue 'System.Windows.Shapes.Rectangle'

        $PresenterPanel | Should -Not -Be $null
        $PresenterPanel.GetType().FullName | Should -Be -ExpectedValue 'System.Windows.Controls.DockPanel'

        $Presenter | Should -Not -Be $null
        $Presenter.GetType().FullName | Should -Be -ExpectedValue 'System.Windows.Controls.ContentPresenter'
        $Presenter.Margin.Left | Should -Be -ExpectedValue 20
        $Presenter.Margin.Top | Should -Be -ExpectedValue 20
        $Presenter.Margin.Right | Should -Be -ExpectedValue 20
        $Presenter.Margin.Bottom | Should -Be -ExpectedValue 20
    }

    It 'Should support TemplateBinding string values in template factory shorthand' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "TemplateBindingFactoryStyle_$Id"
        $Button = [System.Windows.Controls.Button]::new()

        Style $StyleName Button {
            Template {
                Border 'TemplateBorder' {
                    Background: 'TemplateBinding Background'
                }
            }
        }

        $Button.Background = [System.Windows.Media.Brushes]::DarkSlateBlue

        $Vars = New-WPFVariableList -InputObject $Button
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $Button.ApplyTemplate() | Out-Null
        $TemplateBorder = $Button.Template.FindName('TemplateBorder', $Button)

        $TemplateBorder | Should -Not -Be $null
        $TemplateBorder.Background | Should -Not -Be $null
        $TemplateBorder.Background.Color.ToString() | Should -Be -ExpectedValue '#FF483D8B'
    }

    It 'Should support TemplateBinding keyword values in template factory shorthand' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "TemplateBindingKeywordFactoryStyle_$Id"
        $Button = [System.Windows.Controls.Button]::new()

        Style $StyleName Button {
            Template {
                Border 'TemplateBorder' {
                    Background: (TemplateBinding Background)
                }
            }
        }

        $Button.Background = [System.Windows.Media.Brushes]::DarkSlateBlue

        $Vars = New-WPFVariableList -InputObject $Button
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $Button.ApplyTemplate() | Out-Null
        $TemplateBorder = $Button.Template.FindName('TemplateBorder', $Button)

        $TemplateBorder | Should -Not -Be $null
        $TemplateBorder.Background | Should -Not -Be $null
        $TemplateBorder.Background.Color.ToString() | Should -Be -ExpectedValue '#FF483D8B'
    }

    It 'Should reject TemplateBinding keyword usage for invalid properties' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "TemplateBindingKeywordInvalidStyle_$Id"

        {
            Style $StyleName Button {
                Template {
                    Border 'TemplateBorder' {
                        Background: (TemplateBinding NotAProperty)
                    }
                }
            } -ErrorAction Stop
        } | Should -Throw -ExpectedMessage "*TemplateBinding: Property 'NotAProperty' is not a dependency property on type 'System.Windows.Controls.Button'.*"
    }

    It 'Should support owner-qualified attached-property names in template factory shorthand' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "TemplateAttachedPropertyStyle_$Id"
        $Button = [System.Windows.Controls.Button]::new()

        Style $StyleName Button {
            Template {
                Border 'TemplateBorder' {
                    ContentPresenter 'TemplatePresenter' {
                        Content: 'Template content'
                        TextBlock.Foreground: 'Black'
                    }
                }
            }
        }

        $Vars = New-WPFVariableList -InputObject $Button
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $Button.ApplyTemplate() | Out-Null
        $Presenter = $Button.Template.FindName('TemplatePresenter', $Button)

        $Presenter | Should -Not -Be $null
        $ForegroundBrush = $Presenter.GetValue([System.Windows.Documents.TextElement]::ForegroundProperty)
        $ForegroundBrush | Should -Not -Be $null
        $ForegroundBrush.GetType().FullName | Should -Be -ExpectedValue 'System.Windows.Media.SolidColorBrush'
        $ForegroundBrush.Color.ToString() | Should -Be -ExpectedValue '#FF000000'
    }

    It 'Should reject invalid owner-qualified property names in template factory shorthand' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "TemplateInvalidAttachedPropertyStyle_$Id"

        {
            Style $StyleName Button {
                Template {
                    Border 'TemplateBorder' {
                        NotAType.NotAProperty: 42
                    }
                }
            } -ErrorAction Stop
        } | Should -Throw -ExpectedMessage "*Property 'NotAType.NotAProperty' is not a dependency property on type 'System.Windows.Controls.Border'.*"
    }
}
