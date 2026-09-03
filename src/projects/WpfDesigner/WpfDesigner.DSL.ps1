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

App 'Window' {
    $this.Title = 'WPF Designer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700

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

                            TextBlock 'ToolbarPlaceholder' {
                                $this.Text = 'Draggable controls go here.'
                                $this.TextWrapping = 'Wrap'
                                $this.Foreground = '#808080'
                            }
                        }
                    }
                }

                Column 'Expand' {
                    Border 'ViewportPane' {
                        $this.Background = '#F5F5F5'

                        TextBlock 'ViewportPlaceholder' {
                            $this.Text = 'Design surface goes here.'
                            $this.HorizontalAlignment = 'Center'
                            $this.VerticalAlignment = 'Center'
                            $this.Foreground = '#808080'
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
