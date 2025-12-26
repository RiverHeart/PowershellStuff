> [!WARNING]
> Work in progress. Nothing is guaranteed to work as intended.

# Overview

Experimental DSL for building WPF applications in Powershell.

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

## Autocomplete

### Intellisense

TLDR: Yes, in the works.

Auto-complete is tricky. I'm not the sort who's going to mess with VSCode extensions so my only recourse is to use the built-in arg completion provided by Powershell. Unfortunately, it's tricky because while a `CommandAST` object is exposed when defining an `ArgumentCompleterAttribute` it is limited to the immediately surrounding scriptblock. In other words, if we define a `Handler` for a button, we can't see the `Button` command simply by travering the `Parent` property because we've defined `Handler` inside a scriptblock.

Fortunately, I think I found a workaround by getting the invocation args from TabExpansion2 by accessing the callstack. Then I can simply get an unbounded AST object based on our cursor position and use reflection to pass the events back that would apply to the WPF control defined in the parent node.

### VSCode Snippets

See the VSCode snippets in [wpf.code-snippets](../../../.vscode/wpf.code-snippets) to improve the ergonomics of the DSL.

Snippets can be triggered by typing the `wpf-<name of control>` or by pressing `Ctrl+Alt+J`.

## Todo

* Error handling is atrocious. Really need a stack trace instead of a long list of chained errors.

## Notes

### Object References

Because children are defined by functions and added automatically there is an issue regarding node access. If each element were created the regular way you'd have a variable reference but not here. I'm thinking that perhaps that creating a control automatically creates a variable or stores a reference in a hashtable where the lookup key is the name of the control. If I went the automatic variable route I would need to ensure that whitespace was converted to underscores or hyphens. For the Window, it doesn't have a name property so I would need to add one on creation or use something else.

**(2025-12-24)**

I implemented a control lookup system using some helper functions and a hashtable which seems to work. On the other hand, I generally prefer to use native mechanisms and I found out afterwards that WPF supports a name lookup system via the `FindName('name')` method. Like my implementation, it only works if the name has been registered. Unlike my implementation, it's a PITA because it requires instancing a `NameScope` and calling `[NameScope]::SetNameScope($NameScope, $Window)` for `RegisterName('name', $object)` to work. Additionally, this seems to fundamentally alter the WPF app, requiring an `Application` instance to call `$App.Run($Window)`. `$Window.ShowDialog()` simply does nothing when a `Namescope` is set and those might be specific to XAML so it's unclear how to properly use them with programmatically created controls.

Attempts to rerun the app now fail with `Cannot create more than one System.Windows.Application instance in the same AppDomain.` even though I've called `$App.Windows.Close()` to close all windows and the app's shutdown mode is set to `OnLastWindowClose`. This may not even be worthwhile as an application doesn't return anything via stdout. Printing to the console using `Write-Host` is possible but returning a string is a no go. Don't think I will use use the built-in mechanism for this.

## Resources

* https://powershellexplained.com/2017-03-04-Powershell-DSL-example-RDCMan/
* https://app.pluralsight.com/library/courses/powershell-guis-building-wpf-free/table-of-contents
* https://devblogs.microsoft.com/scripting/proxy-functions-spice-up-your-powershell-core-cmdlets/
