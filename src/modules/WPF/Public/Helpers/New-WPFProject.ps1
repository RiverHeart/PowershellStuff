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
                TextBlock 'WelcomeText' {
                    `$this.Margin = 16
                    `$this.Text = 'Welcome to $Name. Start building your app here.'
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
    Import-Module WPF -ErrorAction Stop
}

Import "`$PSScriptRoot/$Name.Styles.ps1"
Import "`$PSScriptRoot/functions"

Window 'Window' {
    `$this.Title = '$Name'
    `$this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    `$this.Width = 1000
    `$this.Height = 700
    `$this.Tag = New-WPFObservableState @{
        # Add app state fields here.
        CurrentView = 'Home'
        IsDirty = `$false
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
