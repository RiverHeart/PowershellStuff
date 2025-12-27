> [!WARNING]
> Work in progress. Nothing is guaranteed to work as intended.

# Overview

Experimental Domain-Specific Language (DSL) for building WPF applications in Powershell.

## Example

The code below creates a window with a couple of buttons. Mandatory arguments get passed as regular function parameters while child objects, properties, and event handlers are declared and returned inside scriptblocks to be processed by the parent control.

More examples can be found in the [Examples](./Examples/) directory.

```powershell
Import-Module ./WPF

Window 'Window' {
    Properties @{
        Title = 'Button Example'
        SizeToContent = 'WidthAndHeight'
    }
    StackPanel "Buttons" {
        Button "EnglishButton" {
            Properties @{
                Content = 'English'
                Width = 100
            }
            Handler "Click" {
                Write-Host "Hello World"
            }
        }
        Button "JapaneseButton" {
            Properties @{
                Content = 'Japanese'
                Width = 100
            }
            Handler "Click" {
                Write-Host "Konichiwa Sekai"
            }
        }
    }
} | Show-WPFWindow
```

## Project Goals

* Convention over configuration (WPF is flexible at the expense of usability)
* Easy to read (everything is nested like HTML)
* Simple things should be easy (shouldn't need to be a programmer or need an IDE to make a window with buttons)
* Composibility (keywords are just functions with aliases)
* Lots of examples (if this is actually useful/productive then sample projects should demonstrate that)
* Xaml escape hatch (should be possible to convert objects to their Xaml representation)

## Autocomplete

TLDR: I can't provide real intellisense but I'm working on some basic stuff using VSCode snippets and Powershell's TabExpansion2.

### Intellisense

I'm not the type of person to mess around with VSCode extensions so my only option is to use what is natively provided by Powershell. Unfortunately, it's trickier than it should be because while the `ArgumentCompleterAttribute` passes a `CommandAST` to the scriptblock that AST is limited to the scriptblock. In other words, because `Handler` is defined inside a scriptblock passed to `Button`, we can't access the part of the AST where `Button` is defined simply by travering the `Parent` property of the `CommandAST`.

I've found a workaround that involves accessing the callstack to get invocation args for TabExpansion2. Among those arguments are the full AST and the cursor position. With those, we can search the AST to get the calling node and find the command value (e.g. `Button`) to determine what values should be returned.

### VSCode Snippets

I'm slowly adding VSCode snippets to [wpf.code-snippets](../../../.vscode/wpf.code-snippets) to make scaffolding the DSL easier.

Snippets can be triggered by typing the `wpf-<control name>` or by pressing `Ctrl+Alt+J`.

## Todo

* Error handling is atrocious. Really need a stack trace instead of a long list of chained errors.

## Notes

### Object References

Because children are defined by functions and added automatically there is an issue regarding node access. If each element were created the regular way you'd have a variable reference but not here. I'm thinking that perhaps that creating a control automatically creates a variable or stores a reference in a hashtable where the lookup key is the name of the control. If I went the automatic variable route I would need to ensure that whitespace was converted to underscores or hyphens. For the Window, it doesn't have a name property so I would need to add one on creation or use something else.

**(2025-12-24)**

I implemented a control lookup system using some helper functions and a hashtable which seems to work. Users can use the `Reference` keyword to lookup any registered object. I found out afterwards that WPF supports a name lookup system via the `FindName('name')` method. Like my implementation, it only works if the name has been registered. Unlike my implementation, it's a PITA because it requires instancing a `NameScope` and calling `[NameScope]::SetNameScope($NameScope, $Window)` for `RegisterName('name', $object)` to work. Additionally, this seems to fundamentally alter the WPF app, requiring an `Application` instance to call `$App.Run($Window)`. `$Window.ShowDialog()` simply does nothing when a `Namescope` is set and those might be specific to XAML so it's unclear how to properly use them with programmatically created controls.

Attempts to rerun the app now fail with `Cannot create more than one System.Windows.Application instance in the same AppDomain.` even though I've called `$App.Windows.Close()` to close all windows and the app's shutdown mode is set to `OnLastWindowClose`. This may not even be worthwhile as an application doesn't return anything via stdout. Printing to the console using `Write-Host` is possible but returning a string is a no go.

While I generally prefer to use native mechanisms where possible, I'm either incapable of understanding it or it is too inflexible to behave how I want so I'm going to ignore it for now.

## Resources

* https://powershellexplained.com/2017-03-04-Powershell-DSL-example-RDCMan/
* https://app.pluralsight.com/library/courses/powershell-guis-building-wpf-free/table-of-contents
