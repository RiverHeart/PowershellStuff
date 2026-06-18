**Feature Proposal: Link Keyword Contract (v1)**

**Summary**
Introduce `Link` as a single entrypoint keyword for binding scenarios. `Link` is syntax sugar only and delegates to existing binding primitives (`Bind`, `BindProperty`, and optionally `Binding` for advanced output-oriented scenarios). The user-facing vocabulary should prefer `-Property` for source member intent, with `-Path` supported as an alias for compatibility with WPF terminology.

**Problem**
The current surface area exposes multiple concepts (`State`, `Bind`, `BindProperty`, `Binding`) that are each valid but increase cognitive load for common scenarios. New users are expected to struggle deciding which keyword to use.

**Goals**
1. Provide one obvious binding entrypoint for most scripts.
2. Keep existing keywords as escape hatches without behavior regressions.
3. Prioritize intent-oriented naming in `Link`:
1. Default source member term: `-Property`
2. Compatibility alias: `-Path`
4. Preserve predictable dispatch rules that are easy to document and test.

**Non-Goals**
1. No replacement or removal of `Bind`, `BindProperty`, or `Binding`.
2. No hidden runtime behavior beyond delegation to existing commands.
3. No forced migration of existing scripts.

**Core Principle**
`Link` should be sugar, not a new binding engine.

**Proposed Contract (v1)**

1. **State-style linking (delegates to `Bind`)**
1. Shape:
1. `Link <TargetProperty> -ToState <StatePropertyName> [-Invert] [-Converter <scriptblock>]`
2. Semantics:
1. `-ToState` is resolved against current window/app state (equivalent source as existing `Bind` usage).
2. `-Invert` and `-Converter` preserve current `Bind` semantics.

2. **WPF binding-style linking (delegates to `BindProperty`)**
1. Shape:
1. `Link <TargetProperty> -Property <SourcePropertyOrPath> [source selector params] [-ScriptBlock <scriptblock>]`
2. Source selector params:
1. `-Self`
2. `-TemplatedParent`
3. `-ElementName`
4. `-Source`
3. Alias:
1. `-Path` is an alias of `-Property` (for WPF-familiar users).
4. Semantics:
1. No selector means inherited `DataContext` behavior, matching current `BindProperty` default.

3. **Advanced binding object mode (optional in v1; can defer)**
1. Shape:
1. `Link -AsBinding -Property <SourcePropertyOrPath> [source selector params] [-ScriptBlock <scriptblock>]`
2. Semantics:
1. Returns a `System.Windows.Data.Binding` (delegates to `Binding`).
2. Intended for advanced APIs such as triggers/templates.

**Parameter Naming Decision**
1. In `Link`, `-Property` is the canonical parameter name for the source side.
2. `-Path` is an alias only.
3. Rationale:
1. `-Property` better communicates intent in common one-segment cases.
2. `-Path` reflects WPF internals and remains available for familiarity and compatibility.

**Dispatch Rules (Deterministic)**
1. If `-ToState` is supplied, dispatch to `Bind`.
2. Else if `-AsBinding` is supplied, dispatch to `Binding`.
3. Else dispatch to `BindProperty` using `-Property`/`-Path` and any source selector.
4. Error on mixed-mode combinations (for example `-ToState` with `-Self`, or `-ToState` with `-AsBinding`).

**Examples**

```powershell
# State -> target property (Bind)
Link Visibility -ToState IsFullScreen -Invert

# DataContext binding (BindProperty with implicit DataContext)
Link Text -Property Count

# Explicit source binding (BindProperty)
Link Text -Property ItemsSource.Count -Source (Reference 'ProcessList')

# WPF terminology-compatible alias
Link Text -Path CurrentFile.Name
```

**Error Contract**
1. Preserve existing underlying error behavior where possible.
2. Add Link-specific validation messages for invalid mode combinations.
3. Forward warnings from delegated commands (for example unresolved DataContext warning behavior).

**Backward Compatibility**
1. Existing scripts using `Bind`, `BindProperty`, and `Binding` continue unchanged.
2. `Link` is additive and optional.

**Testing Requirements**
1. Dispatch tests:
1. `-ToState` routes to `Bind` behavior.
2. `-Property` with selector routes to `BindProperty` behavior.
3. `-AsBinding` returns `Binding` result (if included in v1).
2. Naming tests:
1. `-Property` works as canonical source member parameter.
2. `-Path` alias produces identical behavior.
3. Validation tests:
1. Mixed-mode combinations fail with clear messages.
2. Warning pass-through is preserved.

**Rollout Plan**
1. Implement `Link` keyword as a thin delegating wrapper.
2. Add docs in Keyword Reference with a migration cheat sheet:
1. Old form (`Bind`/`BindProperty`) -> equivalent `Link` form.
3. Keep examples in both styles during transition.

**Open Decisions**
1. Include `-AsBinding` in v1 or defer to v1.1.
2. Whether `-ToState` should accept full dotted path or state-member-only names in v1.
3. Whether to include convenience map operators (`-Map`, `-Invert`) in WPF mode or keep them state-only for clarity.
