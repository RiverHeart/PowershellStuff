# AutoCorrection Phase 3A Handoff

## Current State

- Branch: `AutoCorrectPhase3A`
- HEAD at handoff: `8025e49 Fix EditorEnabled usage`
- Worktree was clean before this handoff file was created.
- Phase 3 is complete.
- Phase 3A is planned but not complete.
- Phase 4 should not begin until Phase 3A satisfies its exit criteria in `AutoCorrection.md`.

Relevant commits:

- `2d53df2 Add New-AstCollectionEdit and update Test-AvoidParameterAttributeBool`
- `7fcb08e Update AutoCorrection plan`
- `8025e49 Fix EditorEnabled usage`

## Why Phase 3A Exists

Phase 3 produced a working preview pipeline, but it also exposed two competing edit models:

- AstEditor validates and queues source edits against an immutable `AstDocument`.
- Nitpick stores the same source coordinates and independently validates ranges, expected text, and overlaps.

The duplicated ownership made a simple rule correction difficult to understand. Moving named-argument removal into AstEditor made the intended boundary clearer: rules identify syntax and correction policy, while AstEditor owns source-edit mechanics and transaction integrity.

## Agreed Ownership

AstEditor owns:

- The authoritative detached text-edit contract.
- Source coordinates, expected text, replacement text, and edit reason.
- Construction from extents, validated offsets, and structural AST operations.
- Stale-text and range validation.
- Conflict detection and atomic batch queueing.
- Rendering, reparsing, diffs, and durable writes.

Nitpick owns:

- Findings and rule execution.
- `Applicability`, `ChangeSetId`, `RuleName`, `FilePathOrContext`, and user-facing descriptions.
- Selecting complete eligible change sets.
- Final rule analysis and result reporting.
- PSScriptAnalyzer `CorrectionExtent` interoperability.

`ChangeSetId` remains Nitpick metadata because a rule declares why edits belong together. AstEditor enforces all-or-nothing queueing for the target batch without knowing about rules or applicability.

## Implemented So Far

### AstEditor

- `New-AstCollectionEdit` is exported.
- It removes an AST element from a delimited collection while preserving intervening trivia.
- It uses parser tokens so commas inside comments are not mistaken for delimiters.
- Tests cover first, middle, last, and only elements, multiline trivia, comments, and nested absolute coordinates.

### Nitpick

- `Test-AvoidParameterAttributeBool` now traverses `Parameter` attributes and their `NamedArguments`.
- The rule delegates `$false` argument removal to `New-AstCollectionEdit`.
- `New-NitpickCorrection` accepts `-TextEdit`.
- Preview tests cover safe removal and final reanalysis.

### Planning

`AutoCorrection.md` now contains:

- An explicit AstEditor/Nitpick ownership boundary.
- Phase 3A as a required phase before Phase 4.
- Updated test ownership, delivery order, and later-phase dependencies.

## Transitional Design That Must Change

The current implementation is an intermediate state, not the Phase 3A target:

1. `AstTextEdit` is still an internal AstEditor class with only offsets, replacement text, and reason.
2. `Add-AstTextEdit` constructs and queues an edit immediately instead of accepting a common detached edit object.
3. `New-AstCollectionEdit` returns an `AstEditor.CollectionEdit` custom object rather than the same contract used by generic text edits.
4. `New-NitpickCorrection -TextEdit` copies edit properties into a separate `NitpickCorrection`; it does not retain the AstEditor edit as the authoritative object.
5. `Resolve-NitpickCorrection` independently validates ranges and expected text, preflights overlaps, and then calls AstEditor, duplicating AstEditor responsibilities.
6. Direct offset construction remains exposed through Nitpick rather than being an AstEditor escape hatch.

## Recommended Implementation Order

### 1. Define the Detached AstEditor Edit Contract

Add a public detached edit model containing:

- `StartLineNumber`
- `EndLineNumber`
- `StartColumnNumber`
- `EndColumnNumber`
- `StartOffset`
- `EndOffset`
- `ExpectedText`
- `ReplacementText`
- `Reason`

Add `New-AstTextEdit` with:

- An extent parameter set.
- A validated offset parameter set tied to one `AstDocument`.
- No queueing side effect.

Offsets remain supported for insertions, token boundaries, and syntax without one suitable AST extent. They move to AstEditor rather than disappearing.

### 2. Unify Structural Edits

Make `New-AstCollectionEdit` return the detached text-edit contract from step 1. Preserve its current collection-oriented API and token-aware behavior.

Update its tests to assert the shared edit type rather than `AstEditor.CollectionEdit`.

### 3. Add Atomic Batch Queueing

Add an AstEditor operation that accepts one document and multiple detached edits. It must:

- Validate every range and expected-text value against the same immutable source snapshot.
- Detect overlaps and same-offset insertion conflicts across the complete batch.
- Queue every edit or none of them.
- Return structured failures identifying the involved edits.
- Avoid Nitpick concepts such as rules, applicability, and change sets.

Keep `Add-AstTextEdit` as a compatibility/convenience surface if useful, but route its validation through the same implementation.

### 4. Make NitpickCorrection an Envelope

Make every native `NitpickCorrection` retain one AstEditor text edit as its source of truth.

Keep these properties in Nitpick:

- `Applicability`
- `ChangeSetId`
- `RuleName`
- `FilePathOrContext`
- `Description`

Preserve existing coordinate, expected-text, and replacement-text reads as convenience projections when practical. Preserve `ToCorrectionExtent()` by projecting from the wrapped edit.

Keep extent-based correction construction as a convenience. Deprecate Nitpick's direct offset parameter set; callers needing offsets should first create a validated AstEditor edit.

### 5. Simplify Resolve-NitpickCorrection

Nitpick should:

1. Group corrections by `ChangeSetId`.
2. Select only complete eligible change sets.
3. Submit the selected target batch to AstEditor atomically.
4. Translate AstEditor failures into rule-aware skipped-correction and conflict results.
5. Render and rerun selected rules after AstEditor accepts the batch.

Remove Nitpick's independent range, expected-text, and overlap validation.

### 6. Update Documentation and Tests

Update AstEditor help and README for the detached edit and atomic batch APIs. Update Nitpick help to describe the envelope model and deprecated direct offset construction.

Run targeted tests first, followed by both full suites.

## Compatibility Constraints

- PowerShell 5.1 and PowerShell 7 are both supported.
- Preserve PSScriptAnalyzer `CorrectionExtent` conversion.
- Preserve line and column coordinates for editor interoperability.
- Existing correction property reads should remain available when practical.
- Do not expose AstEditor internals through Nitpick rule code.
- Do not begin Phase 4 integration while Nitpick still owns duplicate edit validation.

## Validation Commands

```powershell
./tools/Invoke-Test.ps1 -Suite AstEditor -ExitOnError
./tools/Invoke-Test.ps1 -Suite Nitpick -ExitOnError

powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File ./tools/Invoke-Test.ps1 -Suite AstEditor -ExitOnError
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File ./tools/Invoke-Test.ps1 -Suite Nitpick -ExitOnError

git diff --check
```

Before the latest branch-only follow-up commit, the relevant validation completed with:

- PowerShell 7 AstEditor: 58 passed.
- PowerShell 7 Nitpick: 125 passed, 3 planned skips.
- PowerShell 5.1 targeted AstEditor collection tests: 7 passed.
- PowerShell 5.1 targeted Nitpick correction tests: 8 passed.
- PowerShell 5.1 targeted Boolean parameter rule tests: 22 passed.

Run the full suites again from current HEAD before declaring Phase 3A complete.

## Phase 3A Exit Criteria

Phase 3A is complete when:

- Every native Nitpick correction has one authoritative AstEditor edit.
- Generic and structural AstEditor operations return the same detached edit contract.
- AstEditor atomically validates and queues a complete target batch.
- Nitpick no longer independently validates ranges, stale text, or overlaps.
- Compatibility projections and PSScriptAnalyzer conversion remain covered.
- The realigned path passes in PowerShell 5.1 and PowerShell 7.
