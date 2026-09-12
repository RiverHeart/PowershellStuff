using namespace System.Windows

<#
.SYNOPSIS
    Entry point for the WPF Designer project.
#>

$DebugPreference = 'Continue'

Set-Location -Path $PSScriptRoot

Import-Module "$PSScriptRoot/../../modules/WPF" -ErrorAction Stop -Force

Import "$PSScriptRoot/functions"

App 'Window' {
    $this.Title = 'WPF Designer'
    $this.WindowState = [WindowState]::Maximized
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700
    State @{
        SelectedElement = $null
        PropertyPanel   = $null
        WindowFrame     = $null
        WindowModel     = $null
    }

    # Called here (rather than at top-level script scope) so its Resources
    # block picks up $this = Window and scopes styles to Window.Resources.
    Import "$PSScriptRoot/WpfDesigner.Styles.ps1"

    MenuItem '(F)ile/(E)xit' {
        Command 'CloseCommand' 'Ctrl+q' {
            Write-Debug "Close command triggered. Closing window."
            (Get-WPFWindow).Close()
        }
    }

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
                                    Add-WpfDesignerLabel -Canvas (Reference 'DesignSurface') -State (Reference 'Window').Tag -Panel (Reference 'PropertyEditorHost')
                                }
                            }

                            Button 'AddStackPanelButton' {
                                $this.Content = '+ StackPanel'
                                $this.Margin = 0, 4, 0, 0

                                On Click {
                                    Add-WpfDesignerStackPanel -Canvas (Reference 'DesignSurface') -State (Reference 'Window').Tag -Panel (Reference 'PropertyEditorHost')
                                }
                            }

                            Button 'ExportButton' {
                                $this.Content = 'Export'
                                $this.Margin = 0, 8, 0, 0

                                On Click {
                                    $Script = ConvertTo-WpfDesignerScript -Canvas (Reference 'DesignSurface')
                                    [System.Windows.Clipboard]::SetText($Script)
                                    (Reference 'ExportStatusText').Text = 'Copied DSL script to clipboard.'
                                }
                            }

                            TextBlock 'ExportStatusText' {
                                $this.Margin = 0, 4, 0, 0
                                $this.TextWrapping = 'Wrap'
                                $this.Foreground = '#808080'
                            }
                        }
                    }
                }

                Column 'Expand' {
                    Border 'ViewportPane' {
                        $this.Background = '#F5F5F5'

                        Canvas 'DesignSurface' {
                            $this.Background = 'Transparent'

                            # Canvas doesn't clip its children by default, so without this an
                            # oversized/dragged-to-the-edge element would bleed into neighboring panes.
                            $this.ClipToBounds = $true

                            New-WpfDesignerWindowFrame -Canvas $this -State (Reference 'Window').Tag

                            # Deselect when clicking empty canvas. Suppressed for clicks on a
                            # control because Draggable marks that event Handled first.
                            On MouseLeftButtonDown {
                                Clear-WpfDesignerSelection -Canvas $this -State (Reference 'Window').Tag -Panel (Reference 'PropertyEditorHost')
                            }
                        }
                    }
                }

                Column '220' {
                    Border 'PropertyPanelPane' {
                        $this.BorderBrush = '#CCCCCC'
                        $this.BorderThickness = 1, 0, 0, 0

                        ScrollViewer {
                            StackPanel 'PropertyPanelContent' {
                                $this.Margin = 8

                                # Re-scopes DataContext for this panel to whatever is
                                # currently selected, so the fields below can bind to it
                                # with plain inherited-DataContext paths.
                                BindProperty DataContext SelectedElement
                                Bind IsEnabled -To Window.Tag.SelectedElement -Converter { [bool] $_ }

                                Expander 'PropertyPanelExpander' {
                                    $this.Header = 'Properties'
                                    $this.IsExpanded = $true

                                    # Populated per-selection by Update-WpfDesignerPropertyPanel
                                    # (via Select-WpfDesignerElement / Clear-WpfDesignerSelection).
                                    StackPanel 'PropertyEditorHost' {
                                        (Reference 'Window').Tag.PropertyPanel = $this
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
} | Show-WPFWindow
