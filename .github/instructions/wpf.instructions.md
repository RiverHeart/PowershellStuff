---
name: WPF Project Instructions
description: This file contains the WPF project instructions.
applyTo: "src/modules/WPF/**/*.{ps1,psm1,psd1}"
---

# Overview

Experimental DSL for building WPF applications in PowerShell without directly writing XAML.

Primary goal: keep the DSL simple, readable, and behaviorally stable.

# DSL Example

Controls use initializer arguments followed by a trailing script block. Child controls, property assignment, and event handlers are defined inside parent script blocks.

```powershell
Import-Module ./WPF -Force

Window 'Window' {
    $this.Title = 'Button Example'
    $this.Height = 100
    $this.Width = 250

    StackPanel "Buttons" {
        Button "EnglishButton" {
            $this.Content = 'English'
            $this.Width = 100

            When "Click" {
                Write-Host "Hello World"
            }
        }
        Button "JapaneseButton" {
            $this.Content = 'Japanese'
            $this.Width = 100

            When "Click" {
                Write-Host "Konichiwa Sekai"
            }
        }
    }
} | Show-WPFWindow
```

# DSL Contract

Treat these as compatibility constraints unless explicitly requested:

* Control functions use initializer arguments followed by a trailing script block: `Window 'Main' {}`.
* Child controls are declared inside parent script blocks and are processed top-down.
* `$this` is the object currently being configured and is the primary way to set properties.
* `When` binds events within the current control scope.
* `Reference` registers controls for lookup.
* Grid definitions (`ColumnDefinition`, `RowDefinition`) are collection entries, not normal visual children.

# Internal Processing Model

Objects are recursively created and processed top-down. Script blocks apply properties and process child elements through `Update-WPFObject`.

Grid elements such as `ColumnDefinition` and `RowDefinition` have special handling because they do not have a normal parent-child relationship with `Grid`. They are added to `Grid.ColumnDefinitions` and `Grid.RowDefinitions`.

After script block processing, the window object is passed to `Show-WPFDialog`, which calls `ShowDialog()` and then `Close()` when the window exits.

# File Map

Use this mental model when making edits:

* `WPF.psm1`: module wiring, exports, loading behavior.
* `Public/`: user-facing DSL functions.
* `Private/`: helper logic and object-processing internals.
* `Examples/`: executable scenarios used as behavior references.
* `Tests/`: regression protection for DSL behavior.
* `Scripts/Invoke-WPFTestSummary.ps1`: utility to run pester tests with minimal output and a final summary of test results.

# Validation

After making WPF module changes:

* Run pester tests for changed code until tests pass with no failures.
* Once changed code is verified, run Pester tests for `src/modules/WPF/Tests`.
* If behavior changed, run one representative example from `src/modules/WPF/Examples`.
* Confirm no obvious break in nested control creation, event binding, or grid definition handling.
* When running examples unattended (agent/automation), set `WPF_SMOKE_TEST=1` so `Show-WPFWindow` auto-closes after first render and scripts do not hang waiting for manual window close.

# Change Boundaries

Low-risk changes:

* Bug fixes in helper logic
* Better errors and input validation
* Tests and examples that clarify intended behavior

High-risk changes (require extra care and test updates):

* Renaming DSL keywords or public function names
* Altering script block execution order
* Changing how `Reference`, `When`, or `$this` is interpreted
* Modifying dialog lifecycle semantics (`ShowDialog`, `Close`)
