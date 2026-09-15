# Feature Draft: Link Scriptblock Endpoints Escape Hatch

## Status
Deferred

## Summary
Introduce an advanced endpoint form for `Link` using scriptblocks as explicit endpoint references:

```powershell
Link { $this.Text } -To { $state.SearchQuery }
```

This is an escape hatch, not a replacement for canonical syntax.

## Why this exists
Canonical `Link <Source> -To <Target>` is simple and teachable, but it cannot offer member-completion style ergonomics for endpoint selection in every editor path.

Scriptblock endpoints may provide explicitness and completion opportunities without adding more paired parameter forms like `-ToState`/`-FromState`.

## Goals
* Preserve canonical directional syntax as the default and first-class path.
* Provide one advanced escape hatch for explicit endpoint references.
* Avoid reintroducing multiple state/property parameter families.
* Keep one-way default and `-Sync` behavior consistent with current Link contract.

## Non-Goals
* No replacement of canonical `Link <Source> -To <Target>`.
* No implicit support for arbitrary runtime expressions as endpoints.
* No expansion to additional alias-heavy parameter forms (`-ToState`, `-FromProperty`, etc.).

## Proposed shape

```powershell
Link { <source-endpoint-expression> } -To { <target-endpoint-expression> }
```

Illustrative intent (not yet implemented):

```powershell
Link { $this.Text } -To { $state.SearchQuery }
Link { $state.IsLoaded } -To { $this.IsEnabled }
Link { $this.Text } -To { $state.SearchQuery } -Sync
```

## Guardrails (proposed)
* Scriptblock endpoint mode should parse only supported member-access patterns.
* Endpoint scriptblocks should not execute arbitrary side effects.
* Endpoint validation should fail fast with actionable error messages.
* Existing ambiguity rules should still apply when endpoint intent is unclear.

## Risks
* Expression parsing complexity and potential ambiguity.
* Runtime/debugging complexity if endpoint extraction is not deterministic.
* Unexpected behavior if users assume arbitrary script execution semantics.

## Open Questions
* Which endpoint expressions are permitted in v1 of this escape hatch?
* Should endpoint scriptblocks be parsed from AST only, never invoked?
* How should this mode interact with `-FromKind`/`-ToKind` hints?
* Should this mode support `-Sync` from the start or defer until one-way is proven stable?

## Recommendation
Defer implementation. Revisit only if completion/discoverability pain remains after broader usage of the current directional contract.

## Exit Criteria To Reopen
* Repeated usability feedback that canonical string endpoints are a blocker.
* A constrained AST-only design that avoids arbitrary execution.
* A focused test plan that proves deterministic endpoint extraction and error behavior.
