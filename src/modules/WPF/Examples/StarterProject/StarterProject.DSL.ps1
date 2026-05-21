using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Input

<#
.SYNOPSIS
    Entry point for the StarterProject WPF DSL project.
#>

if (
    -not (Get-Module -Name WPF) -and
    (Get-Module -ListAvailable -Name WPF)
) {
    Import-Module WPF -ErrorAction Stop
}

Import "$PSScriptRoot/StarterProject.Styles.ps1"
Import "$PSScriptRoot/functions"

Window 'Window' {
    $this.Title = 'StarterProject'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700
    $this.Tag = New-WPFObservableState @{
        # Add app state fields here.
        CurrentView = 'Home'
        IsDirty = $false
    }

    When Loaded {
        Write-Debug 'StarterProject loaded.'
    }

    # Uncomment this block to add window-wide keyboard shortcuts.
    # When KeyDown {
    #     param($sender, $event)
    #
    #     switch ($event.Key) {
    #         'Escape' {
    #             (Reference 'Window').Close()
    #             $event.Handled = $true
    #         }
    #     }
    # }

    Grid 'Body' {
        Row {
            Column 'Expand' {
                MenuBar 'Menu' {
                    MenuItem '(F)ile/(E)xit' {
                        Command 'CloseCommand' 'Ctrl+q' {
                            Write-Debug "Close command triggered. Closing window."
                            (Reference 'Window').Close()
                        }
                    }
                }
            }
        }

        Row 'Expand' {
            Column {
                StackPanel 'StarterContent' {
                    $this.Margin = 16
                    $this.VerticalAlignment = [VerticalAlignment]::Top

                    TextBlock 'WelcomeText' {
                        $this.Margin = 0, 0, 0, 10
                        $this.Text = 'Welcome to StarterProject. Start building your app here.'
                    }

                    TextBlock 'StyleHint' {
                        $this.Margin = 0, 0, 0, 8
                        $this.Text = 'Try the starter button styles:'
                    }

                    StackPanel 'StarterButtonRow' {
                        $this.Orientation = [System.Windows.Controls.Orientation]::Horizontal
                        $this.Margin = 0, 4, 0, 0
                        Button 'PrimaryExampleButton' {
                            UseStyle 'PrimaryButton'
                            $this.Content = 'Primary Action'
                            $this.Margin = 0, 8, 10, 0
                            Command 'PrimaryExampleCommand' {
                                [System.Windows.MessageBox]::Show('PrimaryButton style example clicked.', 'StarterProject') | Out-Null
                            }
                        }

                        Button 'DangerExampleButton' {
                            UseStyle 'DangerButton'
                            $this.Content = 'Danger Action'
                            $this.Margin = 0, 8, 10, 0
                            Command 'DangerExampleCommand' {
                                [System.Windows.MessageBox]::Show('DangerButton style example clicked.', 'StarterProject') | Out-Null
                            }
                        }

                        Button 'GhostExampleButton' {
                            UseStyle 'GhostButton'
                            $this.Content = 'Ghost Action'
                            $this.Margin = 0, 8, 0, 0
                            Command 'GhostExampleCommand' {
                                [System.Windows.MessageBox]::Show('GhostButton style example clicked.', 'StarterProject') | Out-Null
                            }
                        }
                    }

                    TextBlock 'NextStepText' {
                        $this.Margin = 0, 12, 0, 0
                        $this.Text = 'Replace these examples with your app workflow when ready.'
                    }
                }

            }
        }
    }
} | Show-WPFWindow
