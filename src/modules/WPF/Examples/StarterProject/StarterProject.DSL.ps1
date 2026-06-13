using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Input

<#
.SYNOPSIS
    Entry point for the StarterProject WPF DSL project.
#>

if ($PWD -ne $PSScriptRoot) {
    Set-Location -Path $PSScriptRoot
}

Import-Module ..\.. -ErrorAction Stop -Force

Import "$PSScriptRoot/StarterProject.Styles.ps1"

App 'Window' {
    $this.Title = 'StarterProject'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700
    State @{
        # Add app state fields here.
        CurrentView = 'Home'
        IsDirty = $false
        LastSavedTask = ''
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

    MenuItem '(F)ile/(E)xit' {
        Command 'CloseCommand' 'Ctrl+q' {
            Write-Debug "Close command triggered. Closing window."
            (Reference 'Window').Close()
        }
    }

    Content {
        TextBlock 'WelcomeText' {
            $this.Margin = 0, 0, 0, 10
            $this.Text = 'Welcome to StarterProject. Build one useful interaction in under five minutes.'
        }

        TextBlock 'Step1Text' {
            $this.Margin = 0, 0, 0, 8
            $this.Text = '1) Enter a task name'
        }

        TextBox 'TaskNameInput' {
            $this.Width = 420
            $this.Margin = 0, 0, 0, 8
            $this.Text = 'Prepare onboarding draft'
            When TextChanged {
                $State = (Reference 'Window').Tag
                if ($null -ne $State) {
                    $State.IsDirty = $true
                    $State.CurrentView = 'Editing'
                }
            }
        }

        TextBlock 'Step2Text' {
            $this.Margin = 0, 2, 0, 8
            $this.Text = '2) Save or clear the draft'
        }

        StackPanel 'ActionRow' {
            $this.Orientation = [System.Windows.Controls.Orientation]::Horizontal
            $this.Margin = 0, 0, 0, 0

            Button 'SaveTaskButton' {
                UseStyle 'PrimaryButton'
                $this.Content = 'Save Task'
                $this.Margin = 0, 8, 10, 0
                Command 'SaveTaskCommand' {
                    $TaskName = (Reference 'TaskNameInput').Text
                    if ([string]::IsNullOrWhiteSpace($TaskName)) {
                        (Reference 'SaveResultText').Text = 'Enter a task name before saving.'
                        return
                    }

                    $State = (Reference 'Window').Tag
                    $State.LastSavedTask = $TaskName
                    $State.CurrentView = 'Saved'
                    $State.IsDirty = $false
                    (Reference 'SaveResultText').Text = "Saved task: $TaskName"
                }
            }

            Button 'ClearTaskButton' {
                UseStyle 'GhostButton'
                $this.Content = 'Clear'
                $this.Margin = 0, 8, 10, 0
                Command 'ClearTaskCommand' {
                    (Reference 'TaskNameInput').Text = ''
                    $State = (Reference 'Window').Tag
                    $State.LastSavedTask = ''
                    $State.CurrentView = 'Editing'
                    $State.IsDirty = $true
                    (Reference 'SaveResultText').Text = 'Draft cleared. Enter a new task name.'
                }
            }

        }

        TextBlock 'Step3Text' {
            $this.Margin = 0, 12, 0, 4
            $this.Text = '3) Observe app state changing'
        }

        TextBlock 'SaveResultText' {
            $this.Margin = 0, 0, 0, 6
            $this.Text = 'Saved task: (none yet)'
        }
    }

    StatusBar {
        TextBlock 'CurrentViewText' {
            $this.Margin = 0, 0, 12, 0
            BindProperty Text CurrentView -Source (Reference 'Window').Tag
        }

        TextBlock 'DirtyStateText' {
            $this.Margin = 0, 0, 0, 0
            BindProperty Text IsDirty -Source (Reference 'Window').Tag
        }
    }
} | Show-WPFWindow
