# Feature Proposal: Link Keyword Contract (v1)

## Summary
Introduce `Link` as a single entrypoint keyword for binding scenarios. `Link` is syntax sugar only and delegates to existing binding primitives (`Bind`, `BindProperty`, and optionally `Binding` for advanced output-oriented scenarios). The canonical user-facing shape is source-to-target directional syntax.

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
`Link` should be sugar, not a new binding engine.

## Proposed Contract (v1)

### Directional linking

Directional linking resolves endpoint kinds (Property/State) and delegates to the
appropriate primitive.

**Shape:**
```
Link <Source> -To <Target> [-FromKind Property|State] [-ToKind Property|State]
```

### Advanced binding object mode

optional in v1; can defer

**Shape:**
```
Link -AsBinding -Property <SourcePropertyOrPath> [source selector params] [-ScriptBlock <scriptblock>]
```

**Semantics:**
* Returns a `System.Windows.Data.Binding` (delegates to `Binding`).
* Intended for advanced APIs such as triggers/templates.

**Dispatch Rules (Deterministic)**
1. If `-AsBinding` is supplied, dispatch to `Binding`.
2. Else use directional endpoint resolution and dispatch to `Bind` or `BindProperty`.
3. Error on mixed-mode combinations and ambiguous endpoint resolution without explicit kinds.

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
* Forward warnings from delegated commands (for example unresolved DataContext warning behavior).

### Backward Compatibility
* Existing scripts using `Bind`, `BindProperty`, and `Binding` continue unchanged.
* `Link` is additive and optional.

## Testing Requirements

**Dispatch tests:**
* `-AsBinding` returns `Binding` result (if included in v1).

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
* Include `-AsBinding` in v1 or defer to v1.1.
* Whether to include convenience map operators (`-Map`, `-Invert`) in all directional pairings or only selected ones.
* `-Sync` and update-trigger follow-on behavior is tracked in `RFC-004-Link-SourceTarget-Direction.md`.
