> [!WARNING]
> Work in progress. Nothing is guaranteed to work as intended.

# Overview

Experimental DSL for building WPF applications in Powershell.

## Example

Create a window with a couple of buttons. Mandatory arguments get passed as regular function parameters while child objects, properties, and event handlers are declared and returned inside scriptblocks to be processed by the parent control.

```powershell
Import-Module ./WPF

$Window = Window "Title" 640 480 {
    StackPanel "Buttons" {
        Button "TestButton" "Hello World"
        Button "TestButton2" "Konichiwa Sekai" {
            Properties {
                Width = 100
                Height = 30
            }
            Handler "Click" {
                Write-Host "Foo"
            }
        }
    }
}

Show-WPFWindow $Window
```

## Resources

* https://powershellexplained.com/2017-03-04-Powershell-DSL-example-RDCMan/
* https://app.pluralsight.com/library/courses/powershell-guis-building-wpf-free/table-of-contents
* https://devblogs.microsoft.com/scripting/proxy-functions-spice-up-your-powershell-core-cmdlets/
