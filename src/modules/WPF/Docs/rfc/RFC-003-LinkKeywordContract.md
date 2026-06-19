# Feature Proposal: Link Keyword Contract (v1)

## Summary
Introduce `Link` as a single entrypoint keyword for binding scenarios. `Link` is syntax sugar only and delegates to existing binding primitives (`Bind`, `BindProperty`, and optionally `Binding` for advanced output-oriented scenarios). The user-facing vocabulary should prefer `-Property` for source member intent, with `-Path` supported as an alias for compatibility with WPF terminology.

## Problem
The current surface area exposes multiple concepts (`State`, `Bind`, `BindProperty`, `Binding`) that are each valid but increase cognitive load for common scenarios. New users are expected to struggle deciding which keyword to use.

## Goals
* Provide one obvious binding entrypoint for most scripts.
* Keep existing keywords as escape hatches without behavior regressions.
* Prioritize intent-oriented naming in `Link`:
* Default source member term: `-Property`
* Compatibility alias: `-Path`
* Preserve predictable dispatch rules that are easy to document and test.

## Non-Goals
* No replacement or removal of `Bind`, `BindProperty`, or `Binding`.
* No hidden runtime behavior beyond delegation to existing commands.
* No forced migration of existing scripts.

## Core Principle
`Link` should be sugar, not a new binding engine.

## Proposed Contract (v1)

### State-style linking

Delegates to `Bind`

**Shape:**
```
Link <TargetProperty> -ToState <StatePropertyName> [-Invert] [-Converter <scriptblock>]
```

### Semantics
* `-ToState` is resolved against current window/app state (equivalent source as existing `Bind` usage).
* `-Invert` and `-Converter` preserve current `Bind` semantics.

### WPF binding-style linking

Delegates to `BindProperty`

**Shape:**
```
Link <TargetProperty> -Property <SourcePropertyOrPath> [source selector params] [-ScriptBlock <scriptblock>]
```

**Source selector params:**
* `-Self`
* `-TemplatedParent`
* `-ElementName`
* `-Source`

**Alias:**
* `-Path` is an alias of `-Property` (for WPF-familiar users).

**Semantics:**
* No selector means inherited `DataContext` behavior, matching current `BindProperty` default.

### Advanced binding object mode

optional in v1; can defer

**Shape:**
```
Link -AsBinding -Property <SourcePropertyOrPath> [source selector params] [-ScriptBlock <scriptblock>]
```

**Semantics:**
* Returns a `System.Windows.Data.Binding` (delegates to `Binding`).
* Intended for advanced APIs such as triggers/templates.

**Parameter Naming Decision**
* In `Link`, `-Property` is the canonical parameter name for the source side.
* `-Path` is an alias only.

**Rationale:**
* `-Property` better communicates intent in common one-segment cases.
* `-Path` reflects WPF internals and remains available for familiarity and compatibility.

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

### Error Contract
* Preserve existing underlying error behavior where possible.
* Add Link-specific validation messages for invalid mode combinations.
* Forward warnings from delegated commands (for example unresolved DataContext warning behavior).

### Backward Compatibility
* Existing scripts using `Bind`, `BindProperty`, and `Binding` continue unchanged.
* `Link` is additive and optional.

## Testing Requirements

**Dispatch tests:**
* `-ToState` routes to `Bind` behavior.
* `-Property` with selector routes to `BindProperty` behavior.
* `-AsBinding` returns `Binding` result (if included in v1).

**Naming tests:**
* `-Property` works as canonical source member parameter.
* `-Path` alias produces identical behavior.

**Validation tests:**
* Mixed-mode combinations fail with clear messages.
* Warning pass-through is preserved.

## Rollout Plan
1. Implement `Link` keyword as a thin delegating wrapper.
2. Add docs in Keyword Reference with a migration cheat sheet:
1. Old form (`Bind`/`BindProperty`) -> equivalent `Link` form.
3. Keep examples in both styles during transition.

## Open Decisions
* Include `-AsBinding` in v1 or defer to v1.1.
* Whether `-ToState` should accept full dotted path or state-member-only names in v1.
* Whether to include convenience map operators (`-Map`, `-Invert`) in WPF mode or keep them state-only for clarity.
