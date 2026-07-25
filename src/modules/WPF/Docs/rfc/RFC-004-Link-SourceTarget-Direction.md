# Feature Draft: Link Source->Target Direction and Inference

## Status
Draft

## Why this exists
Current Link usage can still feel ambiguous when users are thinking in natural language rather than binding internals.

This draft reduces ambiguity by enforcing one directional rule:

- Link always reads from source and writes to target.

## Proposed canonical shape

```powershell
Link <Source> -To <Target>
```

Examples:

```powershell
Link IsFileLoaded -To IsEnabled
Link Text -To SearchQuery
```

## Endpoint kinds

Two endpoint namespaces are supported:

- Property: control property on the current object
- State: member on current window state (`Window.Tag`)

When inference is ambiguous, callers must specify kinds.

```powershell
Link IsFileLoaded -To IsEnabled -FromKind State -ToKind Property
Link Text -To SearchQuery -FromKind Property -ToKind State
```

## Inference rules (deterministic)

1. Resolve current control (`$this`) and current window state (`Window.Tag`).
2. For source name, check both namespaces.
3. For target name, check both namespaces.
4. Apply explicit kind flags first if provided.
5. If both namespaces match for either side, fail and require kind flags.
6. If neither namespace matches for either side, fail with endpoint-not-found message.
7. If exactly one namespace matches on each side, proceed.

## Validation rules

1. `-FromKind` and `-ToKind` must be one of `Property` or `State`.
2. Error if source and target resolve to the same endpoint and sync is requested.
3. Error if source endpoint is not readable.
4. Error if target endpoint is not writable.
5. Error messages must include the unresolved or ambiguous endpoint name.

## Sync and update trigger (follow-up)

This draft scopes direction and inference first. Optional follow-up flags:

- `-Sync`
- `-UpdateTrigger PropertyChanged|LostFocus|Explicit`

Follow-up should only be enabled once one-way inference behavior is stable.

## Backward-compat rollout

1. Keep current Link forms working while introducing canonical `Link <Source> -To <Target>`.
2. Publish docs with canonical form first; mark legacy forms as compatibility syntax.
3. Add warnings for legacy forms in a later phase if desired.
4. Remove legacy forms only when project is ready for breaking changes.

## Implementation checklist

1. Add new parameter set for canonical source/target shape.
2. Add optional `-FromKind` and `-ToKind` kind hints.
3. Implement endpoint resolver helper for property/state lookup.
4. Implement ambiguity and not-found error messages.
5. Keep existing parameter sets functional during migration.
6. Update Link help examples to canonical shape.
7. Update Keyword Reference examples to canonical shape.
8. Add migration section old->new examples.

## Test-first plan

### Resolver tests

1. Resolves source as State when only state member exists.
2. Resolves source as Property when only property exists.
3. Resolves target as State when only state member exists.
4. Resolves target as Property when only property exists.
5. Fails as ambiguous when both property and state exist for source.
6. Fails as ambiguous when both property and state exist for target.
7. Honors `-FromKind` disambiguation.
8. Honors `-ToKind` disambiguation.
9. Fails when source resolves nowhere.
10. Fails when target resolves nowhere.

### Link behavior tests

1. `Link <State> -To <Property>` applies source->target updates.
2. `Link <Property> -To <State>` applies source->target updates.
3. `Link <Property> -To <Property>` delegates to binding semantics.
4. `Link <State> -To <State>` supports one-way state mirroring.
5. Error text is actionable for ambiguity.
6. Error text is actionable for not found endpoints.

### Migration tests

1. Existing `-FromState` syntax still works during migration.
2. Existing `-Property` syntax still works during migration.
3. Canonical syntax and legacy syntax produce equivalent behavior where applicable.

## Documentation note

Directionality statement to use consistently:

"Link resolves direction ambiguity by enforcing a single flow model: Source -> Target. In `Link <Source> -To <Target>`, the left side is always read and the right side is always written."
