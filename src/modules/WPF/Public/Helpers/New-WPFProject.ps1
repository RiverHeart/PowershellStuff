<#
.SYNOPSIS
    Scaffolds a new WPF DSL project structure.

.DESCRIPTION
    Creates a repeatable starter project with a main DSL entry script, a style
    file, and conventional folders (functions, images). The generated template
    is intentionally generic and suitable as a starting point for new apps.

.PARAMETER Name
    Name of the project folder and primary DSL files.

.PARAMETER Path
    Parent directory where the project folder should be created. Defaults to the current directory.

.PARAMETER Force
    Overwrite existing scaffold files when the target project already exists.

.PARAMETER Bare
    Create a more minimal scaffold with a starter window and placeholder content,
    without the default File menu shell.

.EXAMPLE
    New-WPFProject MyApp

.EXAMPLE
    New-WPFProject MyApp -Path C:\Projects

.EXAMPLE
    New-WPFProject MyApp -Bare
#>
function New-WPFProject {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string] $Name,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Path = $PWD,

        [switch] $Force,

        [switch] $Bare
    )

    $ProjectRoot = Join-Path $Path $Name
    $FunctionsPath = Join-Path $ProjectRoot 'functions'
    $ImagesPath = Join-Path $ProjectRoot 'images'
    $DslScriptPath = Join-Path $ProjectRoot "$Name.DSL.ps1"
    $StyleScriptPath = Join-Path $ProjectRoot "$Name.Styles.ps1"
    $ReadmePath = Join-Path $ProjectRoot 'README.md'

    if ((Test-Path $ProjectRoot) -and -not $Force) {
        throw "Project path '$ProjectRoot' already exists. Use -Force to overwrite scaffold files."
    }

    if (-not $PSCmdlet.ShouldProcess($ProjectRoot, 'Create WPF project scaffold')) {
        return
    }

    $null = New-Item -Path $ProjectRoot -ItemType Directory -Force
    $null = New-Item -Path $FunctionsPath -ItemType Directory -Force
    $null = New-Item -Path $ImagesPath -ItemType Directory -Force

    $ContentBlock = if ($Bare) {
@"
        Row 'Expand' {
            Column {
                TextBlock 'WelcomeText' {
                    `$this.Margin = 16
                    `$this.Text = 'Welcome to $Name. Replace this placeholder with your app content.'
                }
            }
        }
"@
    } else {
@"
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
                    `$this.Margin = 16
                    `$this.VerticalAlignment = [VerticalAlignment]::Top

                    TextBlock 'WelcomeText' {
                        `$this.Margin = 0, 0, 0, 10
                        `$this.Text = 'Welcome to $Name. Build one useful interaction in under five minutes.'
                    }

                    TextBlock 'Step1Text' {
                        `$this.Margin = 0, 0, 0, 8
                        `$this.Text = '1) Enter a task name'
                    }

                    TextBox 'TaskNameInput' {
                        `$this.Width = 420
                        `$this.Margin = 0, 0, 0, 8
                        `$this.Text = 'Prepare onboarding draft'
                        When TextChanged {
                            `$State = (Reference 'Window').Tag
                            if (`$null -ne `$State) {
                                `$State.IsDirty = `$true
                                `$State.CurrentView = 'Editing'
                            }
                        }
                    }

                    TextBlock 'Step2Text' {
                        `$this.Margin = 0, 2, 0, 8
                        `$this.Text = '2) Save or clear the draft'
                    }

                    StackPanel 'ActionRow' {
                        `$this.Orientation = [System.Windows.Controls.Orientation]::Horizontal
                        `$this.Margin = 0, 0, 0, 0

                        Button 'SaveTaskButton' {
                            UseStyle 'PrimaryButton'
                            `$this.Content = 'Save Task'
                            `$this.Margin = 0, 8, 10, 0
                            Command 'SaveTaskCommand' {
                                `$TaskName = (Reference 'TaskNameInput').Text
                                if ([string]::IsNullOrWhiteSpace(`$TaskName)) {
                                    (Reference 'SaveResultText').Text = 'Enter a task name before saving.'
                                    return
                                }

                                `$State = (Reference 'Window').Tag
                                `$State.LastSavedTask = `$TaskName
                                `$State.CurrentView = 'Saved'
                                `$State.IsDirty = `$false
                                (Reference 'SaveResultText').Text = "Saved task: `$TaskName"
                            }
                        }

                        Button 'ClearTaskButton' {
                            UseStyle 'GhostButton'
                            `$this.Content = 'Clear'
                            `$this.Margin = 0, 8, 10, 0
                            Command 'ClearTaskCommand' {
                                (Reference 'TaskNameInput').Text = ''
                                `$State = (Reference 'Window').Tag
                                `$State.LastSavedTask = ''
                                `$State.CurrentView = 'Editing'
                                `$State.IsDirty = `$true
                                (Reference 'SaveResultText').Text = 'Draft cleared. Enter a new task name.'
                            }
                        }

                    }

                    TextBlock 'Step3Text' {
                        `$this.Margin = 0, 12, 0, 4
                        `$this.Text = '3) Observe app state changing'
                    }

                    TextBlock 'SaveResultText' {
                        `$this.Margin = 0, 0, 0, 6
                        `$this.Text = 'Saved task: (none yet)'
                    }

                    TextBlock 'CurrentViewText' {
                        `$this.Margin = 0, 0, 0, 2
                        BindProperty Text CurrentView -Source (Reference 'Window').Tag
                    }

                    TextBlock 'DirtyStateText' {
                        `$this.Margin = 0, 0, 0, 0
                        BindProperty Text IsDirty -Source (Reference 'Window').Tag
                    }
                }

            }
        }
"@
    }

    @"
using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Input

<#
.SYNOPSIS
    Entry point for the $Name WPF DSL project.
#>

if (
    -not (Get-Module -Name WPF) -and
    (Get-Module -ListAvailable -Name WPF)
) {
    Import-Module WPF -ErrorAction Stop -Force
}

Import "`$PSScriptRoot/$Name.Styles.ps1"
Import "`$PSScriptRoot/functions"

Window 'Window' {
    `$this.Title = '$Name'
    `$this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    `$this.Width = 1000
    `$this.Height = 700
    State @{
        # Add app state fields here.
        CurrentView = 'Home'
        IsDirty = `$false
        LastSavedTask = ''
    }

    When Loaded {
        Write-Debug '$Name loaded.'
    }

    # Uncomment this block to add window-wide keyboard shortcuts.
    # When KeyDown {
    #     param(`$sender, `$event)
    #
    #     switch (`$event.Key) {
    #         'Escape' {
    #             (Reference 'Window').Close()
    #             `$event.Handled = `$true
    #         }
    #     }
    # }

    Grid 'Body' {
$ContentBlock
    }
} | Show-WPFWindow
"@ | Set-Content -Path $DslScriptPath -Encoding UTF8 -Force

    @"
<#
.SYNOPSIS
    Style declarations for the $Name project.

.DESCRIPTION
    Add theme, brush, and style definitions in this file as your project grows.
#>

# Native-ish default button style for new projects.
# Use this implicit style for standard actions, or apply one of the named styles below:
#   UseStyle 'PrimaryButton'
#   UseStyle 'DangerButton'
#   UseStyle 'GhostButton'
Style Button {
    Background: '#F8FAFC'
    Foreground: '#111827'
    BorderBrush: '#8E9AAF'
    BorderThickness: 2
    Padding: 14, 8, 14, 8
    Margin: 0, 8, 0, 0
    FontSize: 14
    MinWidth: 110
    Cursor: ([System.Windows.Input.Cursors]::Hand)
    FocusVisualStyle: $null
    SnapsToDevicePixels: $true
    OverridesDefaultStyle: $true

    Chrome {
        CornerRadius: 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Background: '#E9EEF7'
        BorderBrush: '#7D8BA3'
    }

    Trigger IsPressed $true -Scope Chrome {
        Background: '#DDE6F3'
        BorderBrush: '#6D7D98'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        BorderBrush: '#2563EB'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Background: '#F3F4F6'
        BorderBrush: '#D6DCE5'
    }

    Trigger IsEnabled $false {
        Foreground: '#9CA3AF'
    }
}

Style 'PrimaryButton' Button {
    ExtendStyle Button
    Background: '#0A84FF'
    Foreground: '#FFFFFF'
    BorderBrush: '#086FD5'

    Chrome {
        CornerRadius: 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Background: '#0978E6'
        BorderBrush: '#075FBA'
    }

    Trigger IsPressed $true -Scope Chrome {
        Background: '#0869C9'
        BorderBrush: '#064F97'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        BorderBrush: '#1D4ED8'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Background: '#B6D7FF'
        BorderBrush: '#9FC5EF'
    }

    Trigger IsEnabled $false {
        Foreground: '#E8F2FF'
    }
}

Style 'DangerButton' Button {
    ExtendStyle Button
    Background: '#DC2626'
    Foreground: '#FFFFFF'
    BorderBrush: '#B91C1C'

    Chrome {
        CornerRadius: 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Background: '#C91F1F'
        BorderBrush: '#A31515'
    }

    Trigger IsPressed $true -Scope Chrome {
        Background: '#B31B1B'
        BorderBrush: '#8F1212'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        BorderBrush: '#991B1B'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Background: '#F3B0B0'
        BorderBrush: '#E39A9A'
    }

    Trigger IsEnabled $false {
        Foreground: '#FFF4F4'
    }
}

Style 'GhostButton' Button {
    ExtendStyle Button
    Background: '#FFFFFF'
    Foreground: '#1F2937'
    BorderBrush: '#B8C0CC'

    Chrome {
        CornerRadius: 6
    }

    Trigger IsMouseOver $true -Scope Chrome {
        Background: '#F8FAFC'
        BorderBrush: '#9EA8B8'
    }

    Trigger IsPressed $true -Scope Chrome {
        Background: '#F1F5F9'
        BorderBrush: '#8B97AA'
    }

    Trigger IsKeyboardFocused $true -Scope Chrome {
        BorderBrush: '#2563EB'
    }

    Trigger IsEnabled $false -Scope Chrome {
        Background: '#F8FAFC'
        BorderBrush: '#D2D9E3'
    }

    Trigger IsEnabled $false {
        Foreground: '#A1AAB7'
    }
}

Style TextBox {
    BorderBrush: '#B8C0CC'
    BorderThickness: 1
    Padding: 10, 8
    Margin: 0, 0, 0, 8
    MinHeight: 38
    FontSize: 16
    Foreground: '#111827'
    Background: '#FFFFFF'
    FocusVisualStyle: $null

    Template {
        Border 'InputChrome' {
            CornerRadius: 6
            Background: '#FFFFFF'
            BorderBrush: '#B8C0CC'
            BorderThickness: 1
            SnapsToDevicePixels: $true

            ScrollViewer 'PART_ContentHost' {
                Margin: 10, 8, 10, 8
                Focusable: $false
                HorizontalAlignment: ([HorizontalAlignment]::Stretch)
                VerticalAlignment: ([VerticalAlignment]::Stretch)
            }
        }

        Trigger IsMouseOver $true {
            BorderBrush: '#9EA8B8' -Target 'InputChrome'
        }

        Trigger IsKeyboardFocused $true {
            BorderBrush: '#2563EB' -Target 'InputChrome'
        }

        Trigger IsEnabled $false {
            Background: '#F3F4F6' -Target 'InputChrome'
            BorderBrush: '#D2D9E3' -Target 'InputChrome'
            Foreground: '#A1AAB7'
        }
    }
}
"@ | Set-Content -Path $StyleScriptPath -Encoding UTF8 -Force

    @"
# $Name

Generated with `New-WPFProject`.

## Run

```powershell
./$Name.DSL.ps1
```

The generated scaffold creates an empty ``functions`` folder and a starter style file.
Both are safe to leave empty while you build out the app.
"@ | Set-Content -Path $ReadmePath -Encoding UTF8 -Force

    return [pscustomobject] @{
        ProjectRoot = $ProjectRoot
        DslScript = $DslScriptPath
        StyleScript = $StyleScriptPath
        FunctionsPath = $FunctionsPath
        ImagesPath = $ImagesPath
        ReadmePath = $ReadmePath
    }
}
