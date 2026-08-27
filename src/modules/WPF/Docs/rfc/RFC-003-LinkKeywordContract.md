# Feature Proposal: Link Keyword Contract (v1)

## Summary
Introduce `Link` as a single entrypoint keyword for directional binding scenarios. `Link` is syntax sugar only and dispatches to existing binding primitives or observable-state callbacks. The canonical user-facing shape is source-to-target directional syntax.

## Problem
The current surface area exposes multiple concepts (`State`, `Bind`, `BindProperty`, `Binding`) that are each valid but increase cognitive load for common scenarios. New users are expected to struggle deciding which keyword to use.

## Goals
* Provide one obvious binding entrypoint for most scripts.
* Keep existing keywords as escape hatches without behavior regressions.
* Prioritize directional intent in `Link` with canonical `Link <Source> -To <Target>` syntax.
* Preserve predictable dispatch rules that are easy to document and test.

## Non-Goals
* No replacement or removal of `Bind`, `BindProperty`, or `Binding`.
* No hidden runtime behavior beyond delegation to existing commands.
* No forced migration of existing scripts.

## Core Principle
`Link` should be sugar over existing binding mechanisms, not a new general-purpose binding engine.

## Proposed Contract (v1)

### Directional linking

Directional linking resolves endpoint kinds (Property/State) and delegates to the
appropriate primitive.

**Shape:**
```
Link <Source> -To <Target> [-FromKind Property|State] [-ToKind Property|State]
```

### Endpoint scope and rationale

Canonical `Link` endpoints are exact top-level member names in two namespaces:

* `Property`: a property on the current control (or `-InputObject`)
* `State`: a property on the root window State (`Window.Tag`)

Resolution is eager. `Link` must classify both endpoint kinds before selecting
a connector, and it reports missing or ambiguous endpoints before wiring any
callbacks or WPF bindings.

This exact-member rule is a deliberate v1 contract boundary, not a WPF
limitation. The target-first `Link` API that preceded canonical directional
syntax forwarded WPF paths and `-Source`, `-ElementName`, `-Self`, and
`-TemplatedParent` selectors to `BindProperty`. Those forms were removed when
`Link <Source> -To <Target>` introduced symmetric endpoint inference.

The boundary keeps inference deterministic across connector routes that do not
share one underlying engine:

| Route | Underlying mechanism |
| --- | --- |
| State -> Property | `Bind` callback rooted at `Window.Tag` |
| Property -> Property | self-relative `BindProperty` |
| Property -> State | `BindProperty` with State as the explicit source |
| State -> State | observable State `AddBinding()` callback |

WPF paths and inherited `DataContext` are late-bound: an intermediate object
may be null or replaced after the UI is built, and a `DataContext` member may
not exist when `Link` performs eager inference. The State-to-State callback
route also has no WPF `Binding.Path` or source-selector concept to delegate to.
Supporting those features uniformly would therefore require a larger endpoint
model and nested subscription semantics, not only forwarding another parameter.

This does not mean every richer case is technically difficult. Property-only
paths and selectors could be forwarded to `BindProperty`, as the earlier API
demonstrated. Doing so only for some routes would make identical endpoint syntax
mean different things depending on inferred kinds and would reintroduce much of
the `BindProperty` surface into `Link`. Canonical `Link` instead uses the common,
eagerly validated subset; callers use `BindProperty` when they need WPF binding
semantics.

### Binding object construction

`Link` does not construct or return binding objects. Advanced APIs such as
triggers, templates, and data-grid columns use the existing `Binding` keyword
directly:

```powershell
Binding 'IsEnabled' -TemplatedParent
```

**Dispatch Rules (Deterministic)**
1. Resolve exact endpoint names against current-control Property and root-window State namespaces.
2. Dispatch to the connector for the resolved Property/State pairing.
3. Error on ambiguous endpoint resolution without explicit kinds.

**Examples**

```powershell
# Directional state -> property
Link IsFileLoaded -To IsEnabled

# Directional property -> state
Link Text -To SearchQuery
```

### Error Contract
* Preserve existing underlying error behavior where possible.
* Add Link-specific validation messages for invalid mode combinations.
* Fail endpoint inference before connector dispatch when a member is missing or ambiguous.

### Backward Compatibility
* Existing scripts using `Bind`, `BindProperty`, and `Binding` continue unchanged.
* `Link` is additive and optional.

## Testing Requirements

**Directional tests:**
* Endpoint resolution works for Property and State endpoints.
* Ambiguous endpoint names require explicit `-FromKind`/`-ToKind`.

**Validation tests:**
* Mixed-mode combinations fail with clear messages.
* Warning pass-through is preserved.

## Rollout Plan
1. Implement `Link` keyword as a thin delegating wrapper.
2. Add docs in Keyword Reference with a migration cheat sheet:
1. Old form (`Bind`/`BindProperty`) -> equivalent `Link` form.
3. Keep examples in both styles during transition.

## Open Decisions
* Whether to include convenience map operators (`-Map`, `-Invert`) in all directional pairings or only selected ones.
* `-Sync` and update-trigger follow-on behavior is tracked in `RFC-004-Link-SourceTarget-Direction.md`.

## Resolved Decisions
* `-AsBinding` is excluded from `Link`. Binding-object construction has a
	different return contract and remains the responsibility of `Binding`.
