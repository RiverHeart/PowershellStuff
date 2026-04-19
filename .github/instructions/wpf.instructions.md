---
name: WPF Project Instructions
description: This file contains the WPF project instructions.
applyTo: "src/modules/WPF/**/*.{ps1,psm1,psd1}"
---

# Overview

Experimental DSL for building WPF applications in Powershell without having to touch XAML.

# DSL Example

The code below creates a window with a couple of buttons. Mandatory arguments get passed as regular function parameters while child objects, properties, and event handlers are declared and returned inside scriptblocks to be processed by the parent control.

```powershell
Import-Module ./WPF -Force

Window 'Window' {
    $self.Title = 'Button Example'
    $self.Height = 100
    $self.Width = 250

    StackPanel "Buttons" {
        Button "EnglishButton" {
            $self.Content = 'English'
            $self.Width = 100

            When "Click" {
                Write-Host "Hello World"
            }
        }
        Button "JapaneseButton" {
            $self.Content = 'Japanese'
            $self.Width = 100

            When "Click" {
                Write-Host "Konichiwa Sekai"
            }
        }
    }
} | Show-WPFWindow
```

# Project Goals

* Convention over configuration (WPF is flexible at the expense of usability)
* Easy to read (everything is nested like HTML)
* Simple things should be easy (shouldn't need to be a programmer or need an IDE to make a window with buttons)
* Have fun :)

# Implementation Notes

Function parameters consist of initializer args, such as the name of the object, and end with a scriptblock. For example `Window 'WindowName' {}`.

Objects are recursively created and processed from top to bottom. Each UI element is registered for dynamic lookup using the `Reference` keyword. Scriptblocks apply properties via an automatic variable `$self` and process child elements. Each scriptblock is processed by `Update-WPFObject`.

Grid elements such as `ColumnDefinition` and `RowDefinition` have special handling because they don't have a parent-child relationship with the `Grid` control. Instead, they are added to the `Grid.ColumnDefinitions` and `Grid.RowDefinitions` collections respectively.

Finally, after all scriptblocks have been executed, the window object is passed to `Show-WPFDialog` which calls the `ShowDialog()` method and `Close()` when the window closes.
