# TabCentral

Tab Central is a PowerShell module that allows the user to easily customize and manage `TabExpansion2`, PowerShell's native autocomplete function.

## Table of Contents

* [Why Make It?](#why-make-it)
* [What Is TabExpansion2](#what-is-tabexpansion2)
* [What Does Tab Central Give Me?](#what-does-tab-central-give-me)
* [Prior Art](#prior-art)

## Why Make It?

Tab Central was created for several reasons:
* To provide auto-completion of `$this` for my WPF DSL module.
* To provide an extensible version of `TabExpansion2`.
* To make custom tab expansion opt-in.
* To make custom tab expansion module agnostic.

The first reason stemmed from work on the WPF DSL. I wanted to auto-complete object properties within script blocks such as `Window { $this.^ }`, similar to how it works for classes, and I wanted to do it without creating a VSCode extension. `TabExpansion2` is not extensible without replacing the native function entirely so that's what I did and exporting a customized `TabExpansion2` function from my module was sufficient to solve the problem but introduced a new one. By exporting `TabExpansion2` from the module I was overriding the user's version without explicit permission and that seemed rude.

It was apparent that I would need to make custom Tab Expansion opt-in. Creating a function like `Enable-WPFTabExpansion` would satisfy the goal but still required overriding the user's version of `TabExpansion2` which was a suboptimal outcome. Creating a tab expansion focused module would solve the opt-in problem but required that I make the `TabExpansion2` function extensible.

And so my journey began and ended here.

## What Is TabExpansion2

`TabExpansion` is the name of the built-in PowerShell function that provide tab completion. As the name suggests, the function is called whenever you press `<Tab>` and auto-completes whatever you've typed. `TabExpansion2` works by returning a `CommandCompletion` object which contains an array of `CompletionResults` which PSReadline and VSCode both use to auto-complete your input (or at least I think that's how it works). If you're interested, you can inspect the code yourself by entering `${function:TabExpansion2}` from the terminal.

Unfortunately, it is neither extensible nor well documented.

## What Does Tab Central Give Me?

Tab Central gives you an extensible version `TabExpansion2` and functions that enable you to easily register custom tab completers and result modifiers which I shall heretofore refer to as **Completers** and **Modifiers**. **Completers** are custom auto-complete functions that run before native auto-complete. **Modifiers** are functions which change the completion objects before `TabExpansion2` returns them.

Additionally, Tab Central is designed to allow easy integration with other modules. For instance, registering tab completion for my WPF module is as easy as adding the following to your VSCode profile.

```pwsh
$env:PSModulePath += ';C:\Repos\PowershellStuff\src\modules'
Enable-TabCentral -Verbose
Register-TabCentralHook -Module WPF
```

The above code block adds the path to modules in this repository to `PSModulePath` for discovery, calls `Enable-TabCentral` to enable custom completions and registers all the hooks in the `WPF` module by reading the module metadata. That metadata can be included with any module that wants to enable registration with Tab Central.

You can register individual functions but this is the preferred way to integrate modules.

## Prior Art

* [Nightroman's TabExpansion2](https://github.com/nightroman/FarNet/blob/main/PowerShellFar/TabExpansion2.ps1)
