# Design Philosophy

## Table of Contents

* [Code First](#code-first)
* [Express User Intent](#express-user-intent)
* [One Obvious Way](#one-obvious-way)

## Code First

This DSL is intentionally code-first.

Interoperability with XAML is possible in principle, but the main workflow here is closer to HTML/CSS/JavaScript ergonomics: structure, style, and behavior can be authored in a unified code-first workflow, while still being split across files when that keeps a project maintainable.

## Express User Intent

Many frameworks make complex things easy at the cost of making simple things hard. Even if a complex thing is easy, the way it's exposed to the user may still be unintuitive. The DSL hopes to address these pain points by helping express the user's intent. If something is common that should become a happy path. If something is not obvious the abstraction might need tweaked.

If the quintessential app includes a menu, a body, maybe a footer and/or status bar, it shouldn't be hard to create that. With that in mind, the DSL isn't going to force you to figure out how `Menu` interacts with `DockPanel` and how `Window` can only have a single child container so you need to stick your `DockPanel/Menu` combo into another container so you can place your `Button` and `StatusBar` and figure out how those work. Those are unimportant implementation details when you're just getting started. If you use `App` instead of a `Window`, you get `Menu`, `Content`, `Footer` and `StatusBar` blocks.

Making a control visible depending on a boolean property is another example. In C#/WPF, you need to write a visibility converter for this common scenario. In the DSL you add `State @{ IsFullScreen = $true }` to your `Window`/`App` and `Link Visibility -ToState IsFullScreen -Invert` to each property you want to toggle visibility on and it infers what you want to happen.

## One Obvious Way

I *really* like the [Zen of Python](https://peps.python.org/pep-0020/#the-zen-of-python), especially "There should be one-- and preferably only one --obvious way to do it". If there's one thing that grinds my gears it's the constant flux of framework boilerplate. Progress is going to happen but ideally we design stuff with the flexibility and forethought to evolve rather than be replaced.

The "only one" obvious way ship has already set sail for a lot of things but it is something that I keep in mind as I go. Some custom PSScriptAnalyzer rules might get added in the future to assist with establishing best practice.
