> [!WARNING]
> Work in progress. Nothing is guaranteed to work as intended.

# Overview

Experimental DSL for building WPF applications in Powershell.

## Notes

Because children are defined by functions and added automatically there is an issue regarding node access. If each element were created the regular way you'd have a variable reference but not here. I'm thinking that perhaps that creating a control automatically creates a variable or stores a reference in a hashtable where the lookup key is the name of the control. If I went the automatic variable route I would need to ensure that whitespace was converted to underscores or hyphens. For the Window, it doesn't have a name property so I would need to add one on creation or use something else.

## Example

Create a window with a couple of buttons. Mandatory arguments get passed as regular function parameters while child objects, properties, and event handlers are declared and returned inside scriptblocks to be processed by the parent control.

```powershell
Import-Module ./WPF

Window "Title" 640 480 {
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
} | Show-WPFWindow
```

## Resources

* https://powershellexplained.com/2017-03-04-Powershell-DSL-example-RDCMan/
* https://app.pluralsight.com/library/courses/powershell-guis-building-wpf-free/table-of-contents
* https://devblogs.microsoft.com/scripting/proxy-functions-spice-up-your-powershell-core-cmdlets/
