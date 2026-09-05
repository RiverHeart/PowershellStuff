using namespace System.Windows

<#
.SYNOPSIS
    Entry point for the WPF Designer project.
#>

if ($PWD -ne $PSScriptRoot) {
    Set-Location -Path $PSScriptRoot
}

Import-Module "$PSScriptRoot/../../modules/WPF" -ErrorAction Stop -Force

Import "$PSScriptRoot/functions"

App 'Window' {
    $this.Title = 'WPF Designer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700
    State @{
        SelectedElement = $null
    }

    # Called here (rather than at top-level script scope) so its Resources
    # block picks up $this = Window and scopes styles to Window.Resources.
    Import "$PSScriptRoot/WpfDesigner.Styles.ps1"

    Content {
        Grid 'DesignerGrid' {
            Row 'Expand' {
                Column '180' {
                    Border 'ToolbarPane' {
                        $this.BorderBrush = '#CCCCCC'
                        $this.BorderThickness = 0, 0, 1, 0

                        StackPanel 'ToolbarContent' {
                            $this.Margin = 8

                            TextBlock 'ToolbarHeader' {
                                $this.Text = 'Toolbar'
                                $this.FontWeight = 'Bold'
                                $this.Margin = 0, 0, 0, 8
                            }

                            Button 'AddLabelButton' {
                                $this.Content = '+ Label'

                                On Click {
                                    Add-WpfDesignerLabel -Canvas (Reference 'DesignSurface') -State (Reference 'Window').Tag
                                }
                            }
                        }
                    }
                }

                Column 'Expand' {
                    Border 'ViewportPane' {
                        $this.Background = '#F5F5F5'

                        Canvas 'DesignSurface' {
                            $this.Background = 'Transparent'

                            # Deselect when clicking empty canvas. Suppressed for clicks on a
                            # control because Draggable marks that event Handled first.
                            On MouseLeftButtonDown {
                                Clear-WpfDesignerSelection -Canvas $this -State (Reference 'Window').Tag
                            }
                        }
                    }
                }

                Column '220' {
                    Border 'PropertyPanelPane' {
                        $this.BorderBrush = '#CCCCCC'
                        $this.BorderThickness = 1, 0, 0, 0

                        StackPanel 'PropertyPanelContent' {
                            $this.Margin = 8

                            # Re-scopes DataContext for this panel to whatever is
                            # currently selected, so the fields below can bind to it
                            # with plain inherited-DataContext paths.
                            BindProperty DataContext SelectedElement
                            Bind IsEnabled -To Window.Tag.SelectedElement -Converter { [bool] $_ }

                            TextBlock 'PropertyPanelHeader' {
                                $this.Text = 'Properties'
                                $this.FontWeight = 'Bold'
                                $this.Margin = 0, 0, 0, 8
                            }

                            TextBlock 'PropertyContentLabel' {
                                $this.Text = 'Content'
                                $this.Margin = 0, 0, 0, 2
                            }

                            TextBox 'PropertyContentInput' {
                                $this.Margin = 0, 0, 0, 8
                                BindProperty Text Content -TwoWay
                                Add-WpfDesignerEnterCommit -InputObject $this
                            }

                            TextBlock 'PropertyWidthLabel' {
                                $this.Text = 'Width'
                                $this.Margin = 0, 0, 0, 2
                            }

                            TextBox 'PropertyWidthInput' {
                                $this.Margin = 0, 0, 0, 8
                                BindProperty Text Width -TwoWay
                                Add-WpfDesignerEnterCommit -InputObject $this
                                Add-WpfDesignerPropertyMinimum -InputObject $this -PropertyName Width -Minimum 20 -State (Reference 'Window').Tag
                            }

                            TextBlock 'PropertyHeightLabel' {
                                $this.Text = 'Height'
                                $this.Margin = 0, 0, 0, 2
                            }

                            TextBox 'PropertyHeightInput' {
                                $this.Margin = 0, 0, 0, 8
                                BindProperty Text Height -TwoWay
                                Add-WpfDesignerEnterCommit -InputObject $this
                                Add-WpfDesignerPropertyMinimum -InputObject $this -PropertyName Height -Minimum 20 -State (Reference 'Window').Tag
                            }
                        }
                    }
                }
            }
        }
    }
} | Show-WPFWindow
