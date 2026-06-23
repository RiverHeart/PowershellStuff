# WPF PowerShell

> [!WARNING]
> Experimental project. APIs, syntax, and behavior may change.

A code-first PowerShell DSL for building WPF desktop applications that doesn't require a single line of XAML.

The DSL optimizes for readability, expressing user intent, and reducing boilerplate. Define UI structure, behavior, and styling in one place using nested PowerShell syntax or spread those across a few helper files without rigid MVC or MVVM patterns.

## Table of Contents

* [Flagship Example](#flagship-example)
* [Design Philosophy](#design-philosophy)
  * [Code First](#code-first)
  * [Express User Intent](#express-user-intent)
* [Why Use it](#why-use-it)
* [When This Is Not a Fit](#when-this-is-not-a-fit)
* [Requirements](#requirements)
* [Project Status](#project-status)
* [Project Goals](#project-goals)
* [Getting Started](#getting-started)
* [Prior Art](#prior-art)
* [Documentation](#documentation)
* [Resources](#resources)

## Flagship Example

To get a sense of what you can produce and what the syntax looks like, here is a screenshot and trimmed excerpt from the ImageViewer application in [Examples/ImageViewer](./Examples/ImageViewer). The ImageViewer is a [fully featured app](./Examples/ImageViewer/README.md#features), not a trivial example of sticking an image in a box.

![Image Viewer](./Examples/ImageViewer/ImageViewer.png)

```PowerShell
Import-Module ./WPF -Force

Import "./Examples/ImageViewer/ImageViewer.Styles.ps1"
Import "./Examples/ImageViewer/functions"

App 'Window' {
    $this.Title = 'Image Viewer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.AllowDrop = $true
    $this.WindowState = [WindowState]::Maximized
    State @{
        IsFullScreen = $false
        IsFileLoaded = $false
        IsFitMode = $true
        ZoomLevel = 1.0
        RotationAngle = 0

        CurrentTheme = if (Get-WPFDarkModePreference) { 'Dark' } else { 'Light' }
        FileNavigator = $null
    }

    Use-WPFTheme -Name $this.Tag.CurrentTheme -Root $this

    Key 'Escape' {
        if (-not $this.Tag.IsFullScreen) {
            return
        }

        Set-WPFWindowFullScreen -IsFullScreen $false
        if ($this.Tag.IsFitMode) {
            Invoke-ImageViewerFitToWindow
        }
        $event.Handled = $true
    }

    # Use PreviewKeyDown so navigation still works when focused controls handle KeyDown internally.
    When PreviewKeyDown {
        param($sender, $event)

        switch ($event.Key) {
            'Left' {
                if (Test-ImageViewerShouldNavigate) {
                    Invoke-ImageViewerNavigate -Direction Back
                    $event.Handled = $true
                }
                break
            }
            { $_ -in @('Right', 'Space') } {
                if ($event.Key -eq [System.Windows.Input.Key]::Space -or (Test-ImageViewerShouldNavigate)) {
                    Invoke-ImageViewerNavigate -Direction Forward
                    $event.Handled = $true
                }
                break
            }
        }
    }

    Menu 'Menu' {
        $this.Height = 25
        Link Visibility -ToState IsFullScreen -Invert

        MenuItem '(F)ile/(O)pen' {
            Command 'Open' {
                $Window = Get-WPFWindow
                $FileName = Get-WPFFileSelection -Category Image -Window $Window

                if (-not $FileName) {
                    return
                }

                Invoke-ImageViewerLoadFile -FileName $FileName
            }
        }

        MenuItem '(V)iew/(F)ullScreen' {
            Command 'FullScreen' 'F11' {
                $Window = Get-WPFWindow
                $State = $Window.Tag
                $IsEnteringFullScreen = -not $State.IsFullScreen

                Set-WPFWindowFullScreen -IsFullScreen $IsEnteringFullScreen

                if ($State.IsFitMode) {
                    Invoke-ImageViewerFitToWindow
                }
            }
        }
    }

    Content {
        DockPanel 'MainPanel' {
            $this.LastChildFill = $true

            ScrollViewer 'ScrollViewer' {
                $this.VerticalScrollbarVisibility = [ScrollBarVisibility]::Auto
                $this.HorizontalScrollbarVisibility = [ScrollBarVisibility]::Auto
                $this.Background = 'Transparent'

                Image 'Viewer' {
                    $this.VerticalAlignment = [VerticalAlignment]::Center
                    $this.StretchDirection = [StretchDirection]::DownOnly
                }
            }
        }
    }

    Footer {
        StackPanel 'ButtonPanel' {
            $this.Orientation = [Orientation]::Horizontal
            $this.HorizontalAlignment = [HorizontalAlignment]::Center
            Link Visibility -ToState IsFullScreen -Invert

            Button 'BackButton' {
                Bind IsEnabled -To Window.Tag.IsFileLoaded
                When 'Click' { Invoke-ImageViewerNavigate -Direction Back }
            }

            Button 'ForwardButton' {
                Bind IsEnabled -To Window.Tag.IsFileLoaded
                When 'Click' { Invoke-ImageViewerNavigate -Direction Forward }
            }
        }
    }

    StatusBar {
        Link Visibility -ToState IsFullScreen -Invert

        StatusBarItem 'StatusFileItem' {
            Dock Left

            Label 'StatusFileLabel' {
                $this.Content = 'No image loaded'
            }
        }

        StatusBarItem 'StatusZoomItem' {
            Dock Right

            Label 'StatusZoomLabel' {
                $this.Content = '100%'
            }
        }
    }
} | Show-WPFWindow
```

## Design Philosophy

### Code First

This DSL is intentionally code-first.

Interoperability with XAML is possible in principle, but the main workflow here is closer to HTML/CSS/JavaScript ergonomics: structure, style, and behavior can be authored in a unified code-first workflow, while still being split across files when that keeps a project maintainable.

### Express User Intent

Many frameworks make complex things easy at the cost of making simple things hard. Even if a complex thing is easy, the way it's exposed to the user may still be unintuitive. The DSL hopes to address these pain points by helping express the user's intent. If something is common that should become a happy path. If something is not obvious the abstraction might need tweaked.

If the quintessential app includes a menu, a body, maybe a footer and/or status bar, it shouldn't be hard to create that. With that in mind, the DSL isn't going to force you to figure out how `Menu` interacts with `DockPanel` and how `Window` can only have a single child container so you need to stick your `DockPanel/Menu` combo into another container so you can place your `Button` and `StatusBar` and figure out how those work. Those are unimportant implementation details when you're just getting started. If you use `App` instead of a `Window`, you get `Menu`, `Content`, `Footer` and `StatusBar` blocks.

Making a control visible depending on a boolean property is another example. In C#/WPF, you need to write a visibility converter for this common scenario. In the DSL you add `State @{ IsFullScreen = $true }` to your `Window`/`App` and `Link Visibility -ToState IsFullScreen -Invert` to each property you want to toggle visibility on and it infers what you want to happen.

## Why Use It

- Build WPF applications directly in PowerShell.
- Keep UI layout, event handling, and style definitions close together.
- Reduce boilerplate compared to typical C#/XAML-first workflows.
- Keep setup friction low for beginners and prototyping.

## When This Is Not a Fit

- You need to ship a standalone binary/exe. This project intentionally avoids third-party modules, so binary distribution is not a supported workflow.
- Your team requires a XAML-first designer workflow.
- You need long-term API stability right now.

## Requirements

- Windows
- PowerShell 5 compatibility (project goal)
- A PowerShell editor
- WPF assemblies available on a standard Windows environment

Since Windows PowerShell v5, PowerShell ISE, and WPF come pre-installed on Windows, you already have all of these.

For a more powerful editing experience, you can install [VSCode](https://code.visualstudio.com/download) with the PowerShell extension. When you open this project, you'll be prompted to install extensions recommended by it.

## Project Status

Usable for experimentation and personal tools, still evolving.

Current limitations:

- Editor autocomplete is limited.
- Error reporting still needs improvement.
- Some DSL areas are more mature than others.
- Documentation is still catching up with implementation changes.

## Why Make This?

Many reasons, but a few big ones:

- WinForms is limited compared to WPF
- WPF requires too much ceremony.
- Non-trivial XAML *feels* overwhelming (to me).
- C# is powerful, but the tooling and boilerplate can make it feel heavy.
- I wanted to see if a Powershell DSL for WPF applications was possible. Turns out it is!
- If we're allowed to write legit apps in an interpreted language, like Python, I think it's only fair Powershell gets a shot.

## Project Goals

- Make a fun, practical, leaky abstraction.
- Favor convention over configuration.
- Optimize for user intent.
- Keep syntax easy to read and write.
- Keep barrier to entry low by staying compatible with PowerShell 5.
- Let users compose UI from regular functions rather than opaque tooling.
- Provide enough examples to prove real-world usefulness.

## Getting Started

> [!NOTE]
> TODO: 
> - Move project details into the generated README
> - Focus more on installation... so uh `git clone`

Use `New-WPFProject` to generate a repeatable starter structure for new DSL apps.

```powershell
New-WPFProject MyApp
```

The generated project includes:

- `MyApp.DSL.ps1`
- `MyApp.Styles.ps1`
- `functions/`
- `images/`
- `README.md`

The starter `MyApp.Styles.ps1` now includes a native-ish default `Button` style and named palette styles:

- `PrimaryButton`
- `DangerButton`
- `GhostButton`

Apply named styles with `UseStyle`, for example:

```powershell
Button 'SaveButton' {
    UseStyle 'PrimaryButton'
    $this.Content = 'Save'
}
```

The generated non-bare `MyApp.DSL.ps1` also includes a tiny practical workflow starter:

- A task-name input (`TaskNameInput`)
- Save/Clear actions (`SaveTaskButton`, `ClearTaskButton`)
- Simple observable state feedback (`CurrentView`, `IsDirty`)

Specify a parent directory as the second parameter:

```powershell
New-WPFProject MyApp C:\Projects
```

Use `-Bare` for a more minimal starter without the default File menu shell:

```powershell
New-WPFProject MyApp -Bare
```

## Prior Art

I always knew that there were WPF PowerShell modules out there but I didn't think anyone had made a serious effort at a code first implementation. Most of what I've seen up till this point has just loaded XAML. While searching for more examples to DSL-ify I came across [this tutorial](https://learn.microsoft.com/en-us/archive/msdn-magazine/2011/july/msdn-magazine-windows-powershell-with-wpf-secrets-to-building-a-wpf-application-in-windows-powershell) which uses a `WPK` module. Turns out there were a few projects that attempted what I'm playing with now.


* **PowerBoots (2008):** Early attempt to integrate WPF with PowerShell.
* **WPK (2009):** Microsoft's attempt to standardize a UI-generation kit for administrative tool building.
* **[ShowUI](https://github.com/ShowUI/ShowUI) (2011-2014):** A combined evolution of PowerBoots and WPK.

## Documentation

- [AutomationSmokeMode](./Docs/AutomationSmokeMode.md)
- [Autocomplete Guidance](./Docs/AutoComplete.md)
- [Theme and Style DSL Reference](./Docs/ThemeAndStyleDSL.md)
- [Chrome Adapter Proposal](./Docs/ChromeAdapterProposal.md)
- [Documenting This DSL](./Docs/DocumentingTheDSL.md)
- [Keyword Reference](./Docs/KeywordReference.md)
- [Contribution Checklist](./Docs/ContributionChecklist.md)
- [Keyword Entry Template](./Docs/Templates/KeywordEntryTemplate.md)
- [Maintainer Notes](./Docs/MaintainerNotes.md)
- [Release Readiness Checklist](./Docs/ReleaseReadinessChecklist.md)
- [Repository Migration Plan](./Docs/RepositoryMigrationPlan.md)
- [Development Log](./Docs/DevLog/2026-05.md)
- [Examples](./Examples)

## Resources

- Kevin Marquette's DSL Guide
    - https://powershellexplained.com/2017-02-26-Powershell-DSL-intro-to-domain-specific-languages-part-1/
    - https://powershellexplained.com/2017-03-04-Powershell-DSL-example-RDCMan/
    - https://powershellexplained.com/2017-03-13-Powershell-DSL-design-patterns/
    - https://powershellexplained.com/2017-05-05-PowerShell-TypeExtension-DSL-part-4/
    - https://powershellexplained.com/2017-05-18-Powershell-TypeExtension-DSL-part-5/
- https://app.pluralsight.com/library/courses/PowerShell-guis-building-wpf-free/table-of-contents

