# Feature Proposal: Collector Boundary and Attach Guards (v1)

## Summary
This RFC proposes a minimal, durable pattern to prevent child-collection scope leaks in the WPF DSL while preserving current behavior:

* Keep idempotent attach guards in `Add-WPFObject` as the immediate safety net.
* Emit `Write-Warning` (not `Write-Debug`) when a duplicate attach is prevented, because this reflects a violated construction invariant.
* Introduce explicit collector boundaries so collection intent is owned by collector controls only (for example, `Grid`) and does not leak into nested controls.

## Problem
A runtime failure was observed while constructing a `ListView -> GridView -> GridViewColumn` subtree inside a `Grid` layout:

* `GridViewColumn` was attached once during normal auto-attach.
* The same object was then encountered again via child collection and re-added.
* WPF rejected the second add with:

```
Sharing GridViewColumn among multiple GridViewColumnCollections or adding
the same GridViewColumn into one GridViewColumnCollection more than once is not allowed
```

This indicates a scope leak in collection semantics rather than a one-off `GridView` bug.

## Root Cause Hypothesis
`WPFCollectChildren` is currently propagated through nested scriptblock invocation in a way that can outlive its intended owner context.

In practice:

1. `Grid` enables collection mode for layout declarations (`Row`/`Column`).
2. Nested control keywords can still observe collection mode.
3. Controls that already auto-attach (for correct parent availability) may also return themselves when collection mode is visible.
4. Parent processing then attempts a second attach.

The duplicate attach exception is one symptom of this broader model issue.

## Goals
* Prevent duplicate-add runtime failures.
* Make scope leaks observable and diagnosable.
* Establish a reusable pattern for future collection-oriented controls.
* Preserve existing script compatibility and keep changes incremental.

## Non-Goals
* No immediate rewrite of the DSL attachment pipeline.
* No breaking change to existing control keyword contracts in v1.
* No broad migration to a new state or control registry model.

## Core Principle
Collector intent must be owner-scoped.

Only controls that *own* collection semantics should propagate collection mode. Non-collector controls should not inherit collection behavior by accident.

## Proposed Contract (v1)

### 1. Immediate Safety Net: Idempotent Attach Guard
Keep attach operations idempotent in `Add-WPFObject` for known collection-backed controls.

Current scope includes:
* `GridView.Columns.Add(...)`

If the object already exists in the target collection, skip add.

### 2. Violation Signal: Warning-Level Telemetry
When an idempotent guard prevents a duplicate attach, emit `Write-Warning` with contextual details.

Rationale:
* This is not normal expected flow.
* It indicates a scope-breach/invariant violation.
* Warnings make this visible in development and tests without hard-failing runtime behavior.

### 3. Boundary Model for Collector Scope (Next Step)
Adopt an explicit boundary rule for `WPFCollectChildren`:

1. Default to non-collector mode in nested contexts.
2. Enable collector mode only inside collector-owner contexts (for example, `Grid` while materializing row/column specs).
3. Do not allow collector mode to leak into unrelated nested controls.

This change can be implemented centrally in variable-list/context propagation and validated with targeted regression tests.

### 4. Explicit Ownership Model (Phased)
Collector ownership should be declared explicitly using the existing DSL type-tagging mechanism rather than ad hoc custom object properties.

Proposed mechanism:

1. Introduce a marker type such as `Custom.WPF.CollectorOwner`.
2. Apply that marker to collector-owning keywords at instantiation time.
3. Teach `New-WPFVariableList` to enable collection mode when the current object carries the owner marker.
4. Keep the current type-based fallback during the transition so existing scripts continue to work.

This is a metadata migration, not a property migration. The goal is to move away from `-is` checks against concrete WPF CLR types over time, not to introduce arbitrary PSObject properties for ownership state.

## Why This Pattern
This two-layer pattern balances stability and correctness:

* Layer A (guards) protects users immediately from hard runtime crashes.
* Layer B (boundaries) addresses the architectural source of duplicate replay.

Even after boundaries are tightened, idempotent guards remain valuable defensive programming for dynamic DSL composition.

## Alternatives Considered

### A. Keep only the local GridView guard
Pros:
* Tiny change.

Cons:
* Reactive and control-specific.
* Similar issues can recur for future collection-based controls.

### B. Throw on any duplicate attach attempt
Pros:
* Strict and explicit.

Cons:
* Breaks existing scripts in scenarios that could otherwise recover safely.
* Too disruptive for v1.

### C. Full collector pipeline redesign now
Pros:
* Most architecturally pure.

Cons:
* Large blast radius and higher regression risk.
* Slower path to user-facing stability.

## Testing Strategy

### Existing Regression Coverage
Ensure scenarios where nested controls appear under `Grid` do not throw duplicate-add exceptions.

### Additional Boundary Tests (planned)
* Assert collector flag behavior is owner-scoped.
* Assert nested non-collector controls do not emit collector children due to inherited scope.
* Assert attach guards emit warning when duplicate replay occurs.

## Rollout Plan
1. Ship idempotent guard + warning telemetry (completed for `GridViewColumn`).
2. Add explicit collector-boundary implementation with focused tests.
3. Add explicit collector ownership markers with a compatibility fallback.
4. Document maintainer guidance for new collection-owner keywords.

## Resolved Decisions
* Warning emission stays on by default for duplicate-prevented attaches.
* `WPFStrictMode` may escalate those warnings to terminating errors in CI or other strict environments.
* Guard scope stays minimal for v1: `GridView.Columns.Add(...)` and `DataGrid.Columns.Add(...)` only.
* Collector ownership should be declared explicitly via DSL type metadata, with a compatibility fallback to current type/context inference during migration.
