It's become clear to me that despite the progress made on DSL ergonomics that the template created by `New-WPFProject` would still be overwhelming to beginners. Too much nesting is required for the basic layout of a simple app as demonstrated by this code setting a `MenuItem`. Grid is not a good choice to start out with. A StackPanel would be better but presents its own challenges on integrating a `Menu` and `StatusBar` via docking.

```powershell
Window 'Window' {
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700

    State @{
        # Add app state fields here.
    }

    Grid 'Body' {
        Row {
            Column 'Expand' {
                Menu 'Menu' {
                    MenuItem '(F)ile/(E)xit' {
                        Command 'CloseCommand' 'Ctrl+q' {
                            # Open
                        }
                    }
                    MenuItem '(F)ile/(E)xit' {
                        Command 'CloseCommand' 'Ctrl+q' {
                            # Close
                        }
                    }
                }
            }
        }
        Row {
            Button 'Open' 'OpenCommand'
            Button 'Close' 'CloseCommand'
        }
    }
}
```

I used Matt Pocock's `grill-with-docs` skill for this which was very helpful in nailing down the fine details of how this should work. Unfortunately, I'm not really sure what to do with the `CONTEXT.md` it produced. I don't know that this warrants creating a PRD file.

Essentially, create a wrapper for `Window` called `App` which handles ergonomics. Those ergonomics include accepting `MenuItem` outside of a `Menu`, adding a `Content` block which provides a place for the user's to begin putting their content, and a `StatusBar` which gives users an easy way to place elements at the bottom of the window. I feel that a menu, body, and statusbar, are the core elements of a basic application and creating those should be effortless.

```powershell
Command 'OpenCommand' 'Ctrl+o' {
    Write-Debug "Open command triggered. Opening file."
    # Open file
}

Command 'CloseCommand' 'Ctrl+q' {
    Write-Debug "Close command triggered. Closing window."
    (Reference 'Window').Close()
}

App 'Example' {
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700

    State @{
        # Add app state fields here.
    }

    MenuItem '(F)ile/(O)pen' 'OpenCommand'
    MenuItem '(F)ile/(E)xit' 'CloseCommand'

    Content {
        Button 'Open' 'OpenCommand'
        Button 'Close' 'CloseCommand'
    }

    StatusBar {
        Left {
            TextBlock "Foo"
        }
        Right {
            TextBlock "Bar"
        }
    }
}
```

After establishing what the end result should look like, I was at 130k tokens, which Matt says is near the "dumb zone" for most LLMs, and my attempt to press forward with that session resulted in the agent over-complicating everything. However, I'm unsure it would have been able to manage the complexity anyway. It still throws too much code at problems instead of stepping back to reconsider the implementation.

I speculated on having 'Window' be the default registered name for a 'Window'. It makes sense to have some stable reference to a 'Root' or 'Window' within a given context. Doing that would make it possible to have `App` and `Window` set the title using the first positional parameter. I'm less sure now about the viability of it than before and think I will not tackle it during this implementation. The parent window should be able to get a reference to the child window by providing a context id but you'd have to check what the context id is for the Window. Maybe a child window should have a name registered in the context of the main window and in its own context.
