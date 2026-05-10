# WPF PowerShell

> [!WARNING]
> Experimental project. APIs, syntax, and behavior may change.

A code-first PowerShell DSL for building WPF desktop applications without requiring XAML as the primary authoring model.

The focus is readability and fast iteration: define UI structure, behavior, and styling in one place using nested PowerShell syntax or spread across a few helper files without rigid MVC or MVVM patterns.

## Table of Contents

* [Flagship Example](#flagship-example)
* [Design Philosophy](#design-philosophy)
* [Why Use it](#why-use-it)
* [When This Is Not a Fit](#when-this-is-not-a-fit)
* [Requirements](#requirements)
* [Project Status](#project-status)
* [Project Goals](#project-goals)
* [Documentation](#documentation)
* [Resources](#resources)

## Flagship Example

The following is a screenshot and trimmed excerpt from the ImageViewer application in [Examples/ImageViewer](./Examples/ImageViewer) so you can get a sense of what you can produce and what the syntax looks like. The ImageViewer is a real, non-trivial app.

![Image Viewer](./Examples/ImageViewer/ImageViewer.png)

```PowerShell
Import-Module ./WPF -Force

Import "./Examples/ImageViewer/ImageViewer.styles.ps1"
Import "./Examples/ImageViewer/functions"

Window 'Window' {
    $this.Title = 'Image Viewer'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.AllowDrop = $true
    $this.WindowState = [WindowState]::Maximized
    $this.Tag = New-WPFObservableState @{
        IsFullScreen  = $false
        IsFileLoaded  = $false
        IsFitMode     = $true
        ZoomLevel     = 1.0
        RotationAngle = 0
        CurrentTheme  = if (Get-WPFDarkModePreference) { 'Dark' } else { 'Light' }
        FileNavigator = $null
    }

    Use-WPFTheme -Name $this.Tag.CurrentTheme -Root $this

    When KeyDown {
        param($sender, $event)

        switch ($event.Key) {
            'Escape' {
                if ((Reference 'Window').Tag.IsFullScreen) {
                    Set-WPFWindowFullScreen -IsFullScreen $false
                    Invoke-ImageViewerFitToWindow
                    $event.Handled = $true
                }
            }
            'Left' {
                Invoke-ImageViewerNavigate -Direction Back
                $event.Handled = $true
            }
            { $_ -in @('Right', 'Space') } {
                Invoke-ImageViewerNavigate -Direction Forward
                $event.Handled = $true
            }
        }
    }

    Grid 'Body' {
        Row {
            Column 'Expand' {
                MenuBar 'Menu' {
                    Watch Visibility Window.Tag.IsFullScreen -Invert

                    MenuItem '(F)ile/(O)pen' {
                        Shortcut 'Open' {
                            $fileName = Get-WPFFileSelection -Category Image -Window (Reference 'Window')
                            if ($fileName) {
                                Invoke-ImageViewerLoadFile -FileName $fileName
                            }
                        }
                    }
                }
            }
        }

        Row 'Expand' {
            Column {
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
    }
} | Show-WPFWindow
```

Full example: [Examples/ImageViewer](./Examples/ImageViewer)

The DSL reduces WPF ceremony, but larger desktop applications still carry real complexity.

## Design Philosophy

This DSL is intentionally code-first.

Interoperability with XAML is possible in principle, but the main workflow here is closer to HTML/CSS/JavaScript ergonomics: structure, style, and behavior can be authored in a unified code-first workflow, while still being split across files when that keeps a project maintainable.

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

- WinForms is limited and WPF requires too much ceremony.
- Declarative UI is useful, but XAML is not always the most approachable path.
- C# is powerful, but for quick UI prototyping it can feel heavyweight.
- The project explores whether a readable, practical PowerShell-first WPF DSL is viable.

## Project Goals

- Make a fun, practical, leaky abstraction.
- Favor convention over configuration.
- Keep syntax easy to read and edit.
- Keep barrier to entry low by staying compatible with PowerShell 5.
- Let users compose UI from regular functions rather than opaque tooling.
- Provide enough examples to prove real-world usefulness.

## Project Scaffolding

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

Specify a parent directory as the second parameter:

```powershell
New-WPFProject MyApp C:\Projects
```

Use `-Bare` for a more minimal starter without the default File menu shell:

```powershell
New-WPFProject MyApp -Bare
```

## Documentation

- [AutomationSmokeMode](./Docs/AutomationSmokeMode.md)
- [Autocomplete Guidance](./Docs/AutoComplete.md)
- [Theme and Style DSL Reference](./Docs/ThemeAndStyleDSL.md)
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

- https://PowerShellexplained.com/2017-03-04-PowerShell-DSL-example-RDCMan/
- https://app.pluralsight.com/library/courses/PowerShell-guis-building-wpf-free/table-of-contents

