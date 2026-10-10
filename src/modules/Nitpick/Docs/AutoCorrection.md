# Nitpick Autocorrection

## Status

Phases 0 through 5 are implemented. Later phases remain proposed. This document describes a staged path to native Nitpick autocorrection while preserving PSScriptAnalyzer correction interoperability.

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
3. Collect Nitpick correction metadata around detached AstEditor edits from that snapshot.
4. Let Nitpick select eligible change sets, then let AstEditor atomically validate and queue the target batch.
5. Render all edits in one pass.
6. Reparse and rerun the enabled rules against the rendered text.
7. Write only when validation and stale-source checks succeed.

Offsets do not need adjustment within a batch because every edit refers to the original snapshot. Corrections discovered after rendering belong to a new pass and a new document.

## Ownership Boundary

AstEditor owns source-edit mechanics:

- The authoritative detached text-edit model, including source coordinates, expected text, and replacement text.
- Construction from extents, validated offsets, and structural AST operations.
- Immutable source snapshots, stale-text validation, conflict detection, atomic edit batches, rendering, reparsing, diffs, and durable writes.

Nitpick owns lint and correction policy:

- Rule execution, findings, applicability, rule identity, user-facing descriptions, and PSScriptAnalyzer interoperability.
- `ChangeSetId` as the declaration that corrections produced by a rule must be selected or skipped together.
- Selection of eligible change sets, final reanalysis, summaries, and translation of AstEditor validation results into rule-aware outcomes.

`NitpickCorrection` is a metadata envelope around one AstEditor text edit. Existing edit properties may remain as compatibility projections, but the wrapped AstEditor edit is authoritative. Nitpick does not independently validate ranges, stale text, or overlaps.

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

This contract records the implemented Phase 2 shape. Phase 3A preserves its observable metadata and PSScriptAnalyzer conversion while moving authoritative edit data and validation into AstEditor.

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

### Architectural Finding

The preview proved the workflow but also made Nitpick duplicate AstEditor's range, stale-text, and conflict responsibilities. `Test-AvoidParameterAttributeBool` further demonstrated that structural edit construction belongs in AstEditor. Phase 3A corrects this boundary before the preview workflow becomes part of `Start-Nitpicking`.

## Phase 3A: Realign Edit Ownership (Complete)

### Objective

Establish one authoritative AstEditor edit model and reduce Nitpick corrections to policy metadata around that model before expanding the public fix workflow.

### AstEditor Work

- Introduce a public detached text-edit contract containing source coordinates, expected text, replacement text, and a reason.
- Add `New-AstTextEdit` with extent and validated offset parameter sets.
- Keep offsets available as an escape hatch for insertions, token boundaries, and source not represented by one AST extent.
- Make structural operations such as `New-AstCollectionEdit` return the same detached text-edit contract.
- Add an atomic batch operation that validates every supplied edit against one `AstDocument` and queues all edits or none.
- Make the batch operation own range validation, stale expected-text checks, overlap detection, and same-offset insertion conflicts.
- Return structured validation and conflict information without introducing Nitpick concepts such as rules or applicability.

### Nitpick Work

- Make every native `NitpickCorrection` wrap one AstEditor text edit.
- Retain `Applicability`, `ChangeSetId`, `RuleName`, `FilePathOrContext`, and the user-facing description as Nitpick metadata.
- Preserve existing coordinate, expected-text, and replacement-text properties as compatibility projections when practical.
- Preserve conversion to PSScriptAnalyzer `CorrectionExtent` by projecting from the wrapped edit.
- Keep extent-based correction construction as a convenience that creates an AstEditor edit internally.
- Deprecate direct offset construction in Nitpick; callers needing offsets create a validated AstEditor edit first.
- Remove duplicate range, stale-text, and overlap validation from `Resolve-NitpickCorrection`.
- Select complete eligible change sets in Nitpick, then submit the selected target batch to AstEditor atomically.
- Translate AstEditor batch failures into skipped corrections and conflicts with rule-aware diagnostics.

### Tests

- Constructs detached AstEditor edits from extents and validated offsets.
- Returns the same edit contract from generic and structural AstEditor operations.
- Accepts a valid atomic batch and queues every edit.
- Rejects a stale or conflicting batch without queueing any member.
- Wraps an AstEditor edit in `NitpickCorrection` and preserves Nitpick metadata.
- Preserves compatibility property reads and PSScriptAnalyzer conversion.
- Demonstrates that Nitpick no longer performs independent range or overlap validation.
- Exercises the realigned correction path in PowerShell 5.1 and PowerShell 7.

### Exit Criteria

Every native correction has one authoritative AstEditor edit, AstEditor exclusively enforces source-edit integrity, and Nitpick exclusively decides correction eligibility and reports rule-aware outcomes.

### Implemented Contract

- `New-AstTextEdit` creates detached `AstTextEdit` instances from extents or document-bound offset ranges without queueing them.
- `New-AstCollectionEdit` returns the same detached contract for token-aware structural removal.
- `Add-AstTextEdit -TextEdit` validates a complete batch against one immutable document and queues every edit or none.
- Range, expected-text, overlap, and same-offset insertion validation live in AstEditor.
- `NitpickCorrection.TextEdit` retains the authoritative edit while existing coordinate and text properties remain compatibility projections.
- Nitpick selects complete safe change sets, delegates the target batch to AstEditor, and translates structured AstEditor failures into rule-aware results.
- Extent-based correction construction creates an AstEditor edit internally. Direct Nitpick offset construction remains only as a deprecated compatibility surface.
- The realigned correction path is covered in PowerShell 5.1 and PowerShell 7.

## Phase 4: Integrate Preview with `Start-Nitpicking`

**Status: Complete**

### Objective

Connect the proven preview engine to Nitpick's user-facing command without changing ordinary lint behavior.

### Work

- Refactor `Start-Nitpicking` to collect all findings for a target before emitting output or calculating summaries.
- Route fix mode through `Resolve-NitpickCorrection`.
- Submit the selected target batch through AstEditor's atomic batch API rather than prevalidating edits in Nitpick.
- Expose preview through `Start-Nitpicking -Fix -Preview`; during Phase 4, `-Fix` alone also remains preview-only.
- Emit and count final findings after correction and reanalysis.
- Include rejected corrections, conflicts, rendered text, and the diff in object output.
- Return rendered text for in-memory inputs without modifying files.
- Keep text output concise and direct detailed consumers to object or verbose output.
- Preserve existing behavior when `-Fix` is absent.

### Tests

- Existing non-fix tests remain unchanged.
- Fix-mode tests verify previews, diffs, final severity counts, and corrected in-memory text.
- A failure for one target does not cause another target to be partially applied or reported as successful.

### Exit Criteria

`Start-Nitpicking` exposes a preview-only correction workflow while retaining its existing lint contract outside fix mode.

## Phase 5: Transactional File Application

**Status: Complete**

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

### Implemented Contract

- `New-AstDocument -Path` captures one byte snapshot, its SHA-256 fingerprint, source
  encoding, and a path-bearing AST. Nitpick analyzes that document and submits its
  detached correction batch to the same document for preview and application.
- `Start-Nitpicking -Fix` applies safe, validated corrections to `-Path` targets.
  `-Fix -Preview` and `-Fix -WhatIf` return candidate analysis without writing.
  `-Confirm` controls approval per target. `-Script` inputs remain in-memory even
  when the supplied AST originally came from a file.
- BOM-less files must be valid UTF-8. BOM-marked UTF-8, UTF-16 LE/BE, and UTF-32
  LE/BE retain their original encoding and BOM. Unsupported legacy bytes are
  rejected rather than decoded using a guessed code page.
- `Save-AstDocument` validates parsing, encodes and flushes a uniquely named file
  in the destination directory, checks source and destination fingerprints after
  approval, and commits with `File.Replace` (or `File.Move` for a new destination).
  Atomic replacement failure is reported without a destructive overwrite fallback.
  Owned staging files are cleaned up on failure. Existing newline characters are
  retained; replacements are not globally newline-normalized.
- `Save-AstDocument` returns `AstEditor.WriteResult` with `WasWritten`,
  `WriteStatus`, `ParseErrors`, and `ErrorRecord`. Expected validation/I/O failures
  are explicit structured outcomes, not success. Callers must inspect the result.
- Nitpick returns the existing `Nitpick.CorrectionResult` type for both
  previews and applications. `New-NitpickCorrectionResult` constructs this
  shared schema, including read-failure results. Outcomes are grouped under
  `Findings` (`Original`, `Candidate`, `Final`, `Remaining`, `Fixed`, `Skipped`,
  `Conflicted`, `FailedValidation`) and `Corrections` (`Accepted`, `Fixed`,
  `Skipped`, `Conflicts`) so identically named outcomes for findings and
  corrections, such as `Findings.Skipped` versus `Corrections.Skipped`, stay
  unambiguous. Omitted group properties are empty arrays, optional diagnostics
  are null, and write/reanalysis flags are false. The helper constructs results
  only; it does not analyze or apply corrections.
  `Corrections.Accepted` describes validated selection;
  only `Corrections.Fixed` and `WasWritten` describe committed edits.
  `Findings.Fixed` contains original findings with committed corrections, not
  a claim that every such finding is fully resolved; `Findings.Remaining` holds
  the effective final analysis. Skipped, conflicting, and failed-validation
  findings are separate lists under `Findings`.
- `CandidateText` and `Findings.Candidate` retain preview diagnostics. On failed
  or declined writes, effective findings and threshold counts revert to the
  original analysis; `WasReanalyzed` is false and no correction is reported fixed.
  A stale file is not overwritten or represented as freshly analyzed.
- Write statuses distinguish `Written`, `Preview`, `WhatIf`, `Declined`,
  `InMemory`, `NoChanges`, `Rejected`, `FailedValidation`, `StaleSource`,
  `StaleTarget`, `FailedRead`, and `FailedWrite`. Errors in one target are reported;
  other targets continue unless the caller requests terminating errors.
- Object summaries include fixed-finding, skipped-correction, conflicted-target,
  and failed-target counts while preserving ordinary lint summary text.
- Fingerprints detect byte changes up to the final pre-commit check. They are not
  an OS-level compare-and-swap guarantee against an external writer racing the
  replacement itself. A transaction is per target, not across all input files.

## Phase 6: Structural and Change-Set Fix Providers

**Status: Chunk 6.1 specified; rule migration remains pending**

### Objective

Support corrections that require token awareness, sibling inspection, or coordinated edits beyond one replacement range.

### Work

- Prove one concrete coordinated transform using the existing rule contract before
  introducing a separate provider abstraction or document-aware invocation.
- Require providers to return detached edits through the same AstEditor API.
- Keep providers declarative: they plan edits but do not write files.
- Use change sets for coordinated multi-edit transforms.
- Accept every edit in a change set or skip the complete change set.
- Detect and report conflicts at the change-set level.
- Build on the Phase 3A collection-removal proof by migrating a rule that requires multiple coordinated structural edits.
- Continue emitting ordinary `CorrectionExtent` objects when a structural fix can be represented as a simple replacement for PSScriptAnalyzer.

### Exit Criteria

At least one token-aware rule applies a structural change set through the same preview, validation, conflict, and commit pipeline.

### Chunk 6.1: First Transformation Contract

The first example is `Test-UseIsNotOperator`. Fix-planning code initially remains
inside the rule; "provider" does not imply registration or dispatch machinery.
AstEditor continues to own detached edits and source integrity.

- Offer the fix for a `Not` unary expression whose child is a parenthesized `PipelineAst`
  with exactly one `CommandExpressionAst` containing an `Is` binary expression.
  Retain the existing current-script-block detection scope.
- Redirected or background type-test pipelines remain diagnostic-only: outer
  `-not` observes redirected output or a job rather than the ordinary Boolean
  type-test result. Require no command-expression redirections and no background
  execution before offering a `Safe` fix. Background execution is a PowerShell 7
  case. Keep a comment at this guard explaining why moving negation is unsafe.
- Make two detached, extent-backed edits: delete the unary negation token and
  replace the binary operator token with canonical `-isnot`.
- Locate the negation token at the unary expression's start. Locate the `Is`
  token between the binary expression's left and right operand extents, not by
  searching the whole expression for its first `Is` token. Require one token
  at each location; unexpected token shapes must be reported, not guessed.
- Token extents provide source coordinates and expected text. No document-aware
  rule invocation or new AstEditor helper is required by this example. Token
  acquisition must use the exact full source snapshot, retaining absolute offsets;
  reparsing only a substring would give incorrect coordinates.
- Retain parentheses, whitespace, comments, line endings, operand text, and operator
  text occurring inside strings or variable names. For example,
  `-not ($Value -is [int])` becomes ` ($Value -isnot [int])`; the leading space is
  intentional. `-NOT($Value -IS [int])` becomes `($Value -isnot [int])`.
- Both corrections are `Safe` for this bounded syntax, with rule identity
  `UseIsNotOperator` and one `ChangeSetId` per finding:
  `UseIsNotOperator:<unary-start-offset>:<unary-end-offset>`. IDs include producer
  identity and occurrence, so separate findings are not accidentally coupled.
- Nested matching expressions may be corrected in the same batch. Their two-token
  edit ranges are disjoint even though their finding extents nest:
  `-not (-not ($Value -is [int]) -is [bool])` becomes
  ` ( ($Value -isnot [int]) -isnot [bool])`. Actual overlapping edits from other
  groups still reject the complete selected target batch under the existing policy.
- Do not expand detection to `!`, additional parentheses around the type test,
  multi-element pipelines, pipeline chains, other binary operators, or nested
  script-block scopes in this chunk. Existing recognized inner matches remain
  eligible even when a surrounding expression is not itself recognized.
- After migration, native Nitpick receives the coordinated fix. ScriptAnalyzer
  receives the diagnostic without suggested corrections for this rule, including
  explicit native-finding conversion. Do not retain the current broad replacement
  as a second planner or expose either member of a coordinated group independently.
  Existing simple corrections from other rules remain supported.

`Tests/Public/Rules/UseIsNotOperator.Structural.Contracts.Tests.ps1` proves exact
two-token rendering with current AstEditor APIs. These executable tests specify
syntax and edit mechanics, not a completed rule migration. Skipped contracts name
chunks 6.2 and 6.3 and reserve native output and ScriptAnalyzer behavior until those
chunks implement them. Both PowerShell 5.1 and 7 exercise the syntax contract.

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

AstEditor unit tests own detached edit construction, generic range validation, atomic batch behavior, ordering, conflict detection, rendering, parse validation, stale-source checks, and durable writes.

Nitpick unit tests own correction metadata, compatibility projections, applicability, change-set selection, rule-aware diagnostics, and PSScriptAnalyzer conversion.

Nitpick integration tests own rule collection, multi-rule conflicts, final reanalysis, summary behavior, preview output, file application, and compatibility with native and PSScriptAnalyzer-style corrections.

PowerShell 5.1 and PowerShell 7 must both exercise the correction path because parser extents, encoding defaults, and file replacement behavior cross runtime boundaries.

## MVP Boundary

The preview MVP ends after Phase 4, with Phase 3A as a prerequisite. It supports safe non-overlapping corrections, immutable-snapshot rendering, parse validation, final reanalysis, diffs, and corrected in-memory output without modifying files.

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
3. Implement the initial coordinate-bearing `NitpickCorrection` and its policy metadata.
4. Convert one existing Nitpick rule and implement the standalone preview engine, exposing the duplicated ownership boundary.
5. Realign ownership around detached AstEditor edits and atomic batches.
6. Integrate preview and final-analysis reporting with `Start-Nitpicking`.
7. Harden AstEditor persistence and implement transactional apply.
8. Introduce coordinated structural fix providers.
9. Add bounded multi-pass correction.

This order keeps AstEditor work demand-driven while preventing Nitpick from becoming a second source editor. Detached edits and atomic in-memory batches block public preview integration; encoding preservation, concurrent-change detection, and atomic file replacement block file application but do not need to delay preview.

## Open Decisions

- Whether line-and-column-only third-party corrections can be resolved safely or must remain PSScriptAnalyzer-only.
- Whether final validation requires only successful parsing or also zero newly introduced findings.
- Whether changed severity or message identity is sufficient to match findings across passes.
- Whether final output shows resolved findings by default or only remaining findings plus a fix summary.
- Whether `Review` corrections may be selected interactively or only through explicit rule and applicability filters.
