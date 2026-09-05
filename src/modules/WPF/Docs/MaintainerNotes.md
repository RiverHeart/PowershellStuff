# WPF Maintainer Notes

This page is for maintainers. Keep durable implementation notes, design constraints, and WPF-specific gotchas here.

Use the development log for dated progress entries and in-flight investigation notes. If a backlog item remains relevant beyond a short experiment, promote it to a GitHub issue instead of letting it rot here.

## Backlog Candidates

- Improve error handling so child object failures bubble up cleanly and produce a useful call stack.
- Evaluate global resource support so keyed LinearGradientBrush definitions can be referenced outside Theme contexts (for example, style-only workflows). Current keyed behavior is Theme-only because there is no Application.Resources or module-level global resource registry path yet.
- Replace the `$this`-based auto-attach parent check with a dedicated marker variable (for example, `$__WPFParentContext`) set by `Update-WPFObject` alongside `$this`. This would let keyword functions distinguish "we are inside DSL-managed child processing" from "`$this` happens to be bound because PowerShell auto-populates it for WPF event handler delegates" (see the Design Notes gotcha below). Touches every control keyword's auto-attach check (~25 files) plus `Tests/AttachReturnSemantics.Tests.ps1`, so scope as its own change rather than folding it into unrelated work.
- Investigate a `Style` implementation that doesn't require a `Resources` declaration to get window/element-scoped behavior. Today, bare `Style` (no enclosing `Resources` block) registers into the global `$script:WPFStyleTable` / `$script:WPFImplicitStyleTable` tables, while `Resources { Style ... }` scopes the style to that target's `ResourceDictionary`. See `Resources.ps1` and `Style.ps1` for the `$this`-based dispatch, and `Resources.Tests.ps1` for the leak-prevention test that encodes this contract. Any change must preserve the existing global-vs-scoped distinction rather than silently changing what bare `Style` means.
- Make `Style` behave like `Command` to deprecate `UseStyle`: a single keyword that handles both definition and attachment (`Command 'Save' { ... }` to define, `Command $SaveCommand` or `Command 'Save'` to attach), rather than requiring a separate `UseStyle` call as the only attachment mechanic. This is about unifying the define/attach surface under one keyword, not about dropping the named-style registry in favor of returning a plain variable. Compare `Command.ps1`'s dual-mode dispatch against `Style.ps1` (definition-only) plus `UseStyle.ps1` (attachment-only).

## Design Notes

### Collector Ownership

Collection mode for nested DSL scriptblocks is opt-in and must be declared explicitly by collector-owner keywords.

Current owner set:

* `Grid`

Important distinction:

* A control may consume collection-backed children without being a collector owner.
* For example, `GridView` consumes `GridViewColumn` children, but it should not propagate `WPFCollectChildren` into nested control creation.

Guidance for new keywords:

* If a keyword needs child objects to be returned for later layout or deferred attachment processing, mark the created object with `Custom.WPF.CollectorOwner` via `Add-WPFType`.
* Do not rely on CLR type checks like `-is [System.Windows.Controls.Grid]` to infer collector behavior.
* Add a focused regression test proving the collector owner marker is required and that nested non-owner controls do not over-collect.

### State Input Model

For a summary of attempts to move `State` from explicit hashtable input to scriptblock syntax, including context-binding failures and tradeoffs, see [StateScriptBlockSyntaxInvestigation.md](StateScriptBlockSyntaxInvestigation.md).

### Object References

Because children are defined by functions and added automatically there is an issue regarding node access. If each element were created the regular way you'd have a variable reference but not here. The original options were either automatic variables or a lookup table keyed by control name.

On 2025-12-24 a control lookup system was implemented using helper functions and a hashtable. Users can use the `Reference` keyword to retrieve any registered object.

WPF also has built-in name lookup via `FindName('name')`, but using it programmatically was more awkward than the custom registry. It requires instancing a `NameScope` and calling `[NameScope]::SetNameScope($NameScope, $Window)` before `RegisterName('name', $object)` works.

That approach also appeared to alter application behavior. It pushed execution toward an explicit `Application` instance and `$App.Run($Window)`, while `$Window.ShowDialog()` stopped behaving as expected once a `NameScope` was involved.

Repeated runs also hit `Cannot create more than one System.Windows.Application instance in the same AppDomain.` even after closing app windows and using `OnLastWindowClose` shutdown mode. For now the custom reference registry remains the practical choice.

On 2026-05-09 the registry moved from a single module-scoped hashtable to context-scoped tables keyed by window lifecycle contexts. Each `Window` call creates and activates a context, and `Reference` resolves names against the current object context first. This allows duplicate names like `Window` and `RootGrid` across separate windows without requiring module reloads.

The `Window` keyword now attaches context cleanup to the window `Closed` event so registry state does not accumulate between UI rebuilds in the same session.

The `Window` DSL keyword supports unattended automation via `AutoCloseSeconds`.
If caller scope binds `AutoCloseSeconds`, the `Window` keyword applies that policy
after first render (`ContentRendered`) instead of on `Loaded`. This preserves
startup/render issue coverage for very small values and allows
`AutoCloseSeconds = 0` as an immediate post-render exit.

For runs that should not modify app script parameters, set
`WPF_AUTO_CLOSE_SECONDS` to a numeric value in the environment.

### Auto-Attach vs. Event Handler `$this`

Control keywords (`Label`, `Button`, etc.) decide whether to auto-attach to a parent by checking `$PSCmdlet.GetVariableValue('this')`. This collides with a separate PowerShell behavior: when a scriptblock is invoked as a WPF event handler delegate (for example, via `On Click { ... }`), PowerShell automatically binds `$this` to the sender in that scriptblock's scope. From inside a nested scope there is no way to tell these two cases apart — both are just "`$this` is set in an ancestor scope."

This matters when a keyword like `Label` is called from inside an event handler to build a control programmatically (as opposed to declaratively inside another control's block). The ambient `$this` (the sender) gets mistaken for a DSL parent, and the new control gets auto-attached to the wrong object.

Until the auto-attach check moves to a dedicated marker variable (see Backlog Candidates), the workaround is to explicitly shadow `$this` immediately before calling the keyword:

```powershell
On Click {
    # Label() auto-attaches to $this when set, so clear it first to guarantee
    # the new Label stays unparented until we place it on the canvas.
    $this = $null
    $NewLabel = Label 'SomeLabel' {
        $this.Content = 'Label'
    }
}
```

A `-NoAutoAttach` switch was considered for this generally and rejected as unintuitive for callers; it still exists narrowly on `MenuItem` for its own recursive nested-path construction, which is an unrelated use case.

### GetNewClosure() and Bare Function Calls

Event handler scriptblocks that need to keep a snapshot of outer variables (for example, per-control drag state) typically call `.GetNewClosure()` before assigning them to `Add_<Event>`. This detaches the scriptblock into its own scope for variable lookups, but it also breaks bare-name calls to other functions defined in the same script/module from inside that scriptblock — they fail to resolve at invoke time with "term not recognized," even though the function is clearly defined and in scope everywhere else.

The existing `Draggable` implementation already works around this by capturing the function as a scriptblock reference before closing over it, then invoking it indirectly:

```powershell
$ComputeDraggedPosition = ${function:Get-WPFDraggedPosition}

$MouseMoveHandler = {
    param($sender, $e)
    # ...
    & $ComputeDraggedPosition -AnchorLeft $DragState.AnchorLeft -AnchorTop $DragState.AnchorTop ...
}.GetNewClosure()
```

Capturing the reference via `${function:Name}` works regardless of which file defined the function, as long as it has already been loaded into the session (dot-sourced or imported) before the capturing line executes — this is a session-wide function-table lookup, not a file-scoped one. Any new keyword or consumer code that builds `GetNewClosure()`'d event handlers and needs to call another function from inside them should follow this same capture-and-invoke pattern rather than calling the function by bare name.

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


## Pre-AI Commit

For anyone who cares.

https://github.com/RiverHeart/PowershellStuff/commit/7c7aa15707a1f8f36cc1d0209bcf7658075b39b3
