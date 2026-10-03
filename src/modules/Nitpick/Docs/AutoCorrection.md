# Nitpick Autocorrection

## Status

Phases 0 through 2 are complete; later phases remain proposed. This document describes a staged path to native Nitpick autocorrection while preserving PSScriptAnalyzer correction interoperability.

The Phase 0 contracts live in `AstEditor/Tests/Autocorrection.Contracts.Tests.ps1` and `Nitpick/Tests/Autocorrection.Contracts.Tests.ps1`. Contracts supported by the current implementation execute now. Contracts owned by later phases are discoverable as skipped tests whose messages identify the implementing phase.

## Goals

- Apply multiple corrections without recalculating offsets after each edit.
- Reject overlapping or stale corrections instead of guessing.
- Validate corrected PowerShell before changing a file.
- Provide a preview-first workflow with explicit write semantics.
- Preserve `CorrectionExtent` output for PSScriptAnalyzer consumers.
- Allow future structural fixes without requiring every rule to implement a custom editor.

## Guiding Model

Each file is one correction transaction based on one immutable source snapshot:

1. Parse the source once into an `AstDocument`.
2. Run enabled rules against that snapshot.
3. Collect corrections using coordinates from the same snapshot.
4. Validate and queue a non-conflicting correction batch.
5. Render all edits in one pass.
6. Reparse and rerun the enabled rules against the rendered text.
7. Write only when validation and stale-source checks succeed.

Offsets do not need adjustment within a batch because every edit refers to the original snapshot. Corrections discovered after rendering belong to a new pass and a new document.

## Phase 0: Freeze the Contracts (Complete)

### Objective

Define correction semantics in tests and public help before changing either module.

### Decisions to Record

- Offsets are zero-based half-open ranges: `[StartOffset, EndOffset)`.
- Line and column positions remain one-based for PSScriptAnalyzer compatibility.
- Offsets are relative to the exact source snapshot analyzed by Nitpick.
- A correction may stand alone or belong to a change set containing coordinated edits.
- File-backed and in-memory correction behavior are distinct and explicit.
- Preview is the default until an explicit apply operation is requested.
- Only `Safe` corrections participate in the initial automatic mode.
- The initial conflict policy rejects the complete target batch when change sets overlap.
- Findings and severity counts emitted after fixing come from final analysis.
- Same-offset insertions are rejected until ordering is explicitly modeled.

### Tests

- Describe replacement, deletion, insertion, adjacent ranges, and overlap boundaries.
- Describe file-backed versus in-memory behavior.
- Describe stale source and multi-file failure isolation.
- Express the same coordinate and conflict semantics in AstEditor and Nitpick.

### Exit Criteria

Focused contract tests define the behavior expected by both modules before production implementation begins. Public help also distinguishes current lint behavior from the reserved preview-first fix workflow.

## Phase 1: Generic AstEditor Edit API (Complete)

### Objective

Expose the smallest stable AstEditor surface needed to queue generic corrections without coupling Nitpick to the internal `AstDocument` and `AstTextEdit` classes.

### Work

- Add an exported command such as `Add-AstTextEdit` with offset and extent parameter sets.
- Accept replacement text, a reason, and optional expected source text.
- Validate offsets against the document length.
- Use zero-based, end-exclusive ranges consistently.
- Verify expected source text against `AstDocument.OriginalText` before queuing the edit.
- Return structured information describing the queued edit.
- Replace raw overlap exceptions with a structured conflict error containing both edits and their ranges.
- Reject multiple zero-width insertions at the same offset until an ordering contract is implemented.
- Keep rendering based on the immutable original text.

### Tests

- Queues edits by absolute offset and by `IScriptExtent`.
- Applies several non-overlapping edits in source order.
- Rejects an out-of-range edit.
- Rejects an expected-text mismatch.
- Reports both participants in an overlap conflict.
- Accepts adjacent ranges without treating them as overlaps.
- Rejects insertions sharing an offset with a clear diagnostic.
- Reparses rendered output and reports syntax errors.

### Exit Criteria

Nitpick can queue arbitrary non-overlapping corrections through exported AstEditor commands and obtain rendered text without accessing AstEditor implementation types directly.

### Implemented Contract

- `Add-AstTextEdit` queues edits by zero-based half-open offsets or `IScriptExtent`.
- Optional expected text is matched case-sensitively against the immutable source snapshot.
- The command returns an `AstEditor.TextEditResult` object describing the queued edit.
- Adjacent ranges remain valid, while overlaps and same-offset insertions are rejected.
- Conflict exceptions expose both participants as `ExistingEdit` and `IncomingEdit` entries in `Exception.Data`.
- Rendering and parse validation remain the responsibility of `Resolve-AstDocument`.

## Phase 2: Native Nitpick Correction Model (Complete)

### Objective

Make `NitpickCorrection` a reliable native edit description while retaining conversion to PSScriptAnalyzer's `CorrectionExtent`.

### Work

- Add `StartOffset` and `EndOffset` to corrections created from an `IScriptExtent`.
- Add `ExpectedText` so stale or incorrectly calculated ranges can be rejected.
- Add an applicability classification, initially `Safe`, `Review`, and `Unsafe`.
- Add an optional `ChangeSetId` for corrections that must be accepted or skipped together.
- Add `RuleName` or another stable producer identity for conflict diagnostics.
- Preserve line and column coordinates for display and `CorrectionExtent` conversion.
- Add an explicit offset-based construction path for token-adjusted corrections.
- Define whether line-and-column-only corrections are previewable but not natively applicable until resolved against source text.
- Remove or repurpose the unused `Lines` property after confirming no external dependency.
- Keep file mutation out of `NitpickCorrection.Fix()`; application belongs to a file-level coordinator.

### Tests

- Captures offsets and expected text from an extent.
- Creates a correction from an explicit offset range.
- Converts to an equivalent `CorrectionExtent`.
- Rejects invalid ranges and inconsistent coordinates.
- Covers insertion and multiline ranges.
- Preserves applicability, change-set, and producer metadata.

### Exit Criteria

Every native correction contains enough information to validate and queue itself against the exact source snapshot that produced it.

### Implemented Contract

- Extent-based corrections capture zero-based half-open offsets and exact expected source text.
- Explicit offset corrections require one-based ScriptAnalyzer coordinates and expected text.
- `HasOffsets` distinguishes natively applicable corrections from compatibility-only line/column corrections.
- Expected-text length must equal the offset range length; an empty range and empty expected text represent insertion.
- Applicability is `Safe` by default and may be set to `Review` or `Unsafe`.
- Optional `ChangeSetId` and `RuleName` values preserve change-set and producer identity for later phases.
- Line/column coordinates and `ToCorrectionExtent()` remain unchanged for PSScriptAnalyzer consumers.
- Individual corrections describe edits only and expose no file mutation method.

## Phase 3: Preview MVP

### Objective

Implement useful autocorrection without writing files or first coupling the complete workflow to `Start-Nitpicking`.

### Work

- Introduce a file-level orchestration command such as `Resolve-NitpickCorrection`.
- Accept one file path or one in-memory script and either run selected rules or accept findings produced from the same snapshot.
- Create one `AstDocument` per target and run rules against its AST.
- Normalize native and PSScriptAnalyzer corrections into validated offset ranges.
- Select only corrections marked `Safe` by default.
- Queue corrections through the generic AstEditor API.
- Accept or skip every correction sharing a `ChangeSetId` together.
- Reject or skip a file when independent change sets overlap, and report the responsible rules.
- Render the accepted batch and reparse it.
- Rerun the enabled rules against rendered text.
- Return a structured fix result containing accepted corrections, skipped corrections, conflicts, parse diagnostics, remaining findings, rendered text, and a diff.
- Keep this phase preview-only regardless of target type.
- Convert `Test-AvoidParameterAttributeBool` first, replacing its comma assumption with an extent- or token-derived range before marking the correction `Safe`.

### Tests

- Previews several corrections whose replacement lengths differ.
- Demonstrates that later edit offsets do not shift.
- Skips overlapping corrections with actionable diagnostics.
- Rejects stale expected text.
- Rejects rendered text with new parse errors.
- Confirms corrected findings disappear after rerunning rules.
- Reports findings that remain or are introduced.
- Fixes first, middle, last, and only parameter attribute arguments without damaging commas or trivia.
- Does not modify source files.

### Exit Criteria

A caller can use one correction engine to obtain a validated diff, final findings, and corrected in-memory text without changing disk state.

## Phase 4: Integrate Preview with `Start-Nitpicking`

### Objective

Connect the proven preview engine to Nitpick's user-facing command without changing ordinary lint behavior.

### Work

- Refactor `Start-Nitpicking` to collect all findings for a target before emitting output or calculating summaries.
- Route fix mode through `Resolve-NitpickCorrection`.
- Expose preview through `Start-Nitpicking -Fix -WhatIf` or the command surface selected in Phase 0.
- Emit and count final findings after correction and reanalysis.
- Include rejected and conflicting corrections in object output.
- Return rendered text for in-memory inputs.
- Keep text output concise and direct detailed consumers to object or verbose output.
- Preserve existing behavior when `-Fix` is absent.

### Tests

- Existing non-fix tests remain unchanged.
- Fix-mode tests verify previews, diffs, final severity counts, and corrected in-memory text.
- A failure for one target does not cause another target to be partially applied or reported as successful.

### Exit Criteria

`Start-Nitpicking` exposes a preview-only correction workflow while retaining its existing lint contract outside fix mode.

## Phase 5: Transactional File Application

### Objective

Allow the previewed correction transaction to be committed safely.

### AstEditor Hardening

- Record a source fingerprint when creating an `AstDocument`.
- Compare the current file with the original snapshot immediately before writing.
- Preserve source encoding, BOM, and newline style.
- Write to a temporary file in the destination directory and replace the target atomically where supported.
- Clean up temporary files after failures.
- Continue supporting `ShouldProcess`, `WhatIf`, and `Confirm`.
- Return structured write results rather than relying only on success output or exceptions.

### Nitpick Work

- Make `Start-Nitpicking -Fix` apply the same transaction produced by preview.
- Require file-backed targets for direct writes; in-memory inputs return rendered text.
- Calculate summary counts and `ErrorOn` behavior from the final analysis pass.
- Distinguish fixed, skipped, conflicted, failed-validation, and remaining findings.
- Avoid writing a file when its source fingerprint changed after analysis.

### Tests

- Applies a validated correction batch to a temporary file.
- Supports `WhatIf` without changing the file.
- Rejects a file changed between analysis and commit.
- Preserves encoding, BOM, and newline style.
- Leaves the original file intact when validation or replacement fails.
- Reports final findings and threshold status after successful correction.

### Exit Criteria

`Start-Nitpicking -Fix` can safely update file-backed targets using the same observable transaction produced by preview.

## Phase 6: Structural and Change-Set Fix Providers

### Objective

Support corrections that require token awareness, sibling inspection, or coordinated edits beyond one replacement range.

### Work

- Define a fix-provider contract that receives the current `AstDocument`, finding, and rule context.
- Require providers to queue edits through the same AstEditor API.
- Keep providers declarative: they plan edits but do not write files.
- Use change sets for coordinated multi-edit transforms.
- Accept every edit in a change set or skip the complete change set.
- Detect and report conflicts at the change-set level.
- Migrate a rule with punctuation or trivia concerns as the first proof, such as removal of a `$false` parameter attribute argument and its adjacent comma.
- Continue emitting ordinary `CorrectionExtent` objects when a structural fix can be represented as a simple replacement for PSScriptAnalyzer.

### Exit Criteria

At least one token-aware rule applies a structural change set through the same preview, validation, conflict, and commit pipeline.

## Phase 7: Optional Multiple Passes

### Objective

Support fixes that expose additional safe fixes after the first batch, after single-pass behavior is stable.

### Work

- Add an explicit pass limit, defaulting to one initially.
- Build a fresh `AstDocument` and rerun analysis after each committed in-memory render.
- Stop when no applicable corrections remain.
- Detect no-progress cycles by hashing rendered text between passes.
- Detect oscillation when a previously seen source hash returns.
- Report corrections and findings by pass.
- Commit to disk once after the final successful pass rather than once per pass.

### Exit Criteria

Multiple passes converge predictably or stop with a clear pass-limit or cycle diagnostic.

## Test Ownership

AstEditor unit tests own generic range validation, ordering, conflict detection, rendering, parse validation, stale-source checks, and durable writes.

Nitpick unit tests own correction metadata, coordinate conversion, expected-text validation, applicability, change sets, and PSScriptAnalyzer conversion.

Nitpick integration tests own rule collection, multi-rule conflicts, final reanalysis, summary behavior, preview output, file application, and compatibility with native and PSScriptAnalyzer-style corrections.

PowerShell 5.1 and PowerShell 7 must both exercise the correction path because parser extents, encoding defaults, and file replacement behavior cross runtime boundaries.

## MVP Boundary

The preview MVP ends after Phase 4. It supports safe non-overlapping corrections, immutable-snapshot rendering, parse validation, final reanalysis, diffs, and corrected in-memory output without modifying files.

The first file-writing release ends after Phase 5. Structural providers, multi-edit change sets, and multiple correction passes remain follow-up capabilities.

## Conflict and Failure Policy

- Never silently choose between overlapping change sets.
- Accept all members of a change set or skip all of them.
- Treat an expected-text mismatch as stale analysis, not as an ordinary overlap.
- Do not write output that introduces parse errors.
- Do not write when the source file differs from the analyzed snapshot.
- Preserve the original file if any commit step fails.
- Report rule names, descriptions, and source ranges for every skipped correction.

## Proposed Result Model

A correction run should return one result per target with fields similar to:

```text
Path
OriginalFingerprint
PassCount
AcceptedCorrections
SkippedCorrections
Conflicts
ParseErrors
OriginalFindings
FinalFindings
RemainingFindings
IntroducedFindings
Diff
CandidateText
RenderedText
WasReanalyzed
WasWritten
WriteStatus
```

The exact type can be introduced after the preview workflow demonstrates which fields callers need.

## Suggested Delivery Order

1. Freeze correction, coordinate, and conflict semantics.
2. Export and test the generic AstEditor edit API.
3. Extend `NitpickCorrection` with offsets, expected text, applicability, change sets, and producer identity.
4. Convert one existing Nitpick rule and implement the standalone preview engine.
5. Integrate preview and final-analysis reporting with `Start-Nitpicking`.
6. Harden AstEditor persistence and implement transactional apply.
7. Introduce structural change-set providers using one token-aware rule as proof.
8. Add bounded multi-pass correction.

This order keeps AstEditor work demand-driven. Generic edit queuing blocks the preview MVP; encoding preservation, concurrent-change detection, and atomic replacement block file application but do not need to delay preview.

## Open Decisions

- Whether preview should be `Start-Nitpicking -Fix -WhatIf`, a `-PreviewFix` switch, or a separate command.
- Whether a conflict skips only the involved change sets or the entire file transaction.
- Whether line-and-column-only third-party corrections can be resolved safely or must remain PSScriptAnalyzer-only.
- Whether final validation requires only successful parsing or also zero newly introduced findings.
- Whether changed severity or message identity is sufficient to match findings across passes.
- Whether final output shows resolved findings by default or only remaining findings plus a fix summary.
- Whether `Review` corrections may be selected interactively or only through explicit rule and applicability filters.
- Whether AstEditor becomes a required Nitpick dependency or its generic edit engine is extracted into a smaller shared module.
