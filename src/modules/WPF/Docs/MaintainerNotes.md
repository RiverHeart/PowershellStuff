# WPF Maintainer Notes

This page is for maintainers. Keep durable implementation notes, design constraints, and WPF-specific gotchas here.

Use the development log for dated progress entries and in-flight investigation notes. If a backlog item remains relevant beyond a short experiment, promote it to a GitHub issue instead of letting it rot here.

## Backlog Candidates

- Improve error handling so child object failures bubble up cleanly and produce a useful call stack.

## Design Notes

### Object References

Because children are defined by functions and added automatically there is an issue regarding node access. If each element were created the regular way you'd have a variable reference but not here. The original options were either automatic variables or a lookup table keyed by control name.

On 2025-12-24 a control lookup system was implemented using helper functions and a hashtable. Users can use the `Reference` keyword to retrieve any registered object.

WPF also has built-in name lookup via `FindName('name')`, but using it programmatically was more awkward than the custom registry. It requires instancing a `NameScope` and calling `[NameScope]::SetNameScope($NameScope, $Window)` before `RegisterName('name', $object)` works.

That approach also appeared to alter application behavior. It pushed execution toward an explicit `Application` instance and `$App.Run($Window)`, while `$Window.ShowDialog()` stopped behaving as expected once a `NameScope` was involved.

Repeated runs also hit `Cannot create more than one System.Windows.Application instance in the same AppDomain.` even after closing app windows and using `OnLastWindowClose` shutdown mode. For now the custom reference registry remains the practical choice.

On 2026-05-09 the registry moved from a single module-scoped hashtable to context-scoped tables keyed by window lifecycle contexts. Each `Window` call creates and activates a context, and `Reference` resolves names against the current object context first. This allows duplicate names like `Window` and `RootGrid` across separate windows without requiring module reloads.

The `Window` keyword now attaches context cleanup to the window `Closed` event so registry state does not accumulate between UI rebuilds in the same session.

`Show-WPFWindow` supports an unattended smoke-test mode controlled by the `WPF_SMOKE_TEST` environment variable. When enabled (`1`, `true`, `yes`, or `on`), windows auto-close right after first render by setting `DialogResult = $false`. This allows DSL apps to run in automation and emit debug output without a human closing UI windows.

### RelayCommand

While working on menu support, the initial expectation was that `ICommand` could be attached directly to a `MenuItem` with a simple command object. In practice, usable command wiring in WPF revolved around a `RelayCommand` implementation and, initially, `CommandBinding`.

On 2025-12-27 the conclusion was that a plain click handler was the most practical solution because implementing a full `RelayCommand` path in a lightweight way was messy. `CommandManager` availability was a major complication when experimenting with `Add-Type -TypeDefinition` and .NET Core.

On 2026-01-06 a `RelayCommand` implementation was borrowed from `CommunityToolkit.Mvvm`. Direct command assignment worked, which suggests `CommandManager` and binding behavior were the confusing pieces rather than the basic `ICommand` hookup itself.

The remaining design concern is syntax. `RelayCommand { Execute Code } { Can Execute Code }` works, but two adjacent scriptblocks do not fit the rest of the DSL particularly well.

Current minimal working example:

```powershell
MenuItem '_Exit' {
    Handler Click {
        $Window = Reference 'Window'
        $Window.Close()
    }
}
```

**2026-05-05**

See [RelayCommandSyntaxProposal.md](RelayCommandSyntaxProposal.md) for the proposed DSL syntax, behavior contract, and phased implementation plan.

## Notes Hygiene

- Keep this file for information another maintainer would need six months from now.
- Move dated progress updates into `Docs/DevLog/`.
- Move durable backlog items into GitHub issues once the module gets its own repository.
- Keep private scratch notes outside the repo until they are worth sharing.
