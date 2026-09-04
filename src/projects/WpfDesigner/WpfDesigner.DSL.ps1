using namespace System.Windows

<#
.SYNOPSIS
    Entry point for the WPF Designer project.
#>

if ($PWD -ne $PSScriptRoot) {
    Set-Location -Path $PSScriptRoot
}

if (-not (Get-Module -Name WPF)) {
    Import-Module "$PSScriptRoot/../../modules/WPF" -ErrorAction Stop -Force
}

Import "$PSScriptRoot/functions"

App 'Window' {
    $this.Title = 'WPF Designer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700

    Resources {
        # Scoped to this Window so it only affects Labels placed on the design surface.
        Style Label {
            BorderBrush: '#999999'
            BorderThickness: 1
            Padding: 4

            Trigger IsMouseOver $true {
                BorderBrush: '#2563EB'
                Background: '#EFF6FF'
            }
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
                                    Add-WpfDesignerLabel -Canvas (Reference 'DesignSurface')
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
                        }
                    }
                }

                Column '220' {
                    Border 'PropertyPanelPane' {
                        $this.BorderBrush = '#CCCCCC'
                        $this.BorderThickness = 1, 0, 0, 0

                        StackPanel 'PropertyPanelContent' {
                            $this.Margin = 8

                            TextBlock 'PropertyPanelHeader' {
                                $this.Text = 'Properties'
                                $this.FontWeight = 'Bold'
                                $this.Margin = 0, 0, 0, 8
                            }

                            TextBlock 'PropertyPanelPlaceholder' {
                                $this.Text = 'Selected control properties go here.'
                                $this.TextWrapping = 'Wrap'
                                $this.Foreground = '#808080'
                            }
                        }
                    }
                }
            }
        }
    }
} | Show-WPFWindow
