# Plan: Correction Remodel and Summary Reporting

Status: Phases 1–3 implemented (correction container remodel; applied lifecycle rename; summary counters and formatting); Phase 4 pending. Decisions ratified in [CONTEXT.md](../CONTEXT.md#correction-lifecycle) and [ADR 0003](adr/0003-corrections-are-whole-fixes-with-atomic-edits.md).

## Motivation

Two problems share one root:

1. `Start-Nitpicking` summaries count `Report.EffectiveFindings`, so a fix-mode run that corrects every finding reports `0 findings` directly beneath a visible correction, and in-memory applies are counted nowhere (`CommittedCorrections` requires a file write).
2. `NitpickCorrection` is one record per text edit, with logical fixes expressed through a stringly `ChangeSetId`. The intended model was always one correction = one possible fix for a finding. Downstream components (selection, counting, formatting, PSSA interop) each re-derive the grouping.

The remodel makes the fix the unit of choice and the edit the unit of application, after which the summary counters fall out naturally.

## Decided semantics

- **Correction** = one complete fix for a finding, containing its `TextEdits` (AstEditor `AstTextEdit[]`), applied all-or-nothing. `ChangeSetId` is retired from the rule-author API.
- **Applied** replaces **committed**: an accepted correction whose edits took effect in the effective text — `Written` for file targets or `InMemory` for script targets. The in-memory counting gap closes as a side effect.
- **Selection policy**: only `Safe` corrections are auto-applied, and at most one per finding. A finding with multiple `Safe` corrections has all of its corrections skipped with an "ambiguous alternatives" reason (never silently choose). The recorded skips are the future input for interactive selection under `FixMode Guided`.
- **Summary counters**: `FindingCount` and the severity counters describe *detected* findings (original analysis). `CorrectedFindingCount` counts findings with an applied correction; `CorrectableFindingCount` counts findings with an accepted correction that was not applied (preview, WhatIf, declined, failed write). `UnresolvedFindingCount` counts effective findings. Corrected/correctable/unresolved need not sum to detected; that is documented, not repaired.
- **Thresholds unchanged**: `-ErrorOn` continues to gate on effective findings via its own counter.
- **PSSA interop**: `ToDiagnosticRecord` exports only single-edit corrections; multi-edit corrections are dropped at that boundary (ADR 0003).

## Phase 1 — Remodel `NitpickCorrection` as a fix container

- `NitpickCorrection` (Nitpick.psm1): replace the single `TextEdit` and its per-edit projections (`StartLineNumber`..`EndOffset`, `ExpectedText`, `ReplacementText`, `ChangeSetId`) with `TextEdits : AstTextEdit[]`. Retain `RuleId`, `Applicability`, `Description`, `FilePathOrContext`. Keep a single-edit convenience constructor 
(`ViolationExtent` + `ReplacementText`) that builds the one-element `TextEdits` array; per-edit `Reason` defaults to the correction `Description`.
- `New-NitpickCorrection`: accept `-TextEdit <AstTextEdit[]>`; remove `-ChangeSetId`; keep the extent/replacement convenience parameters for single-edit fixes.
- Rules: `Test-UseIsNotOperator` emits one correction containing both edits; verify the other two rules emit single-edit corrections through the convenience path.
- `Resolve-NitpickCorrectionProposal`: delete the change-set reconstruction dictionary. Iterate findings → corrections; apply the Safe-only and at-most-one-Safe-per-finding policy; queue all edits of all selected corrections in one `Add-AstTextEdit` call (per-target atomic queueing, rendering, validation, and reanalysis are unchanged). `AcceptedCorrections`/`SkippedCorrections`/`Conflicts` reference corrections; map AstEditor conflict edits back to their owning corrections.
- `Get-NitpickCorrectionCount` dissolves: a correction already is the user-facing unit. `Format-NitpickCorrection` keeps per-edit reason headers and carets (driven by queued edits) and counts corrections for its trailer.
- `ToDiagnosticRecord`: export single-edit corrections as `CorrectionExtent`s; skip multi-edit corrections with the existing boundary comment updated.

## Phase 2 — Applied lifecycle rename

- `Application.CommittedCorrections` → `AppliedCorrections`, populated for `Written` **and** `InMemory`.
- `Report.FindingsWithCommittedCorrections` → `FindingsWithAppliedCorrections`; add `FindingsWithAcceptedCorrections` (attribution against `Proposal.AcceptedCorrections`), computed by the target coordinator alongside the existing attribution loop.
- `New-NitpickCorrectionResult` validation: applied corrections require application status `Written` or `InMemory`; `Written` additionally requires write evidence. Preview, WhatIf, Declined, and failures never populate `AppliedCorrections`.
- No compatibility aliases, per the module's migration precedent.

## Phase 3 — Summary

- `NitpickSummary`: `FindingCount`, `ErrorCount`, `WarningCount`, `InformationCount` switch to detected findings. Add `CorrectedFindingCount`, `CorrectableFindingCount`, `UnresolvedFindingCount`, and a `FixMode` field (for formatting). Remove `FindingsWithAppliedCorrectionsCount` (renamed from `FindingsWithCommittedCorrectionsCount` in Phase 2, where it also began counting in-memory applies). `SkippedCorrectionCount` now counts corrections (fixes), not edits.
- `Start-Nitpicking`: count detected from the pre-correction finding set (parse-error findings included); unresolved from `Report.EffectiveFindings`; corrected/correctable from the report attribution lists. Pipeline object output continues to emit effective findings. The `-ErrorOn` threshold counter is untouched.
- `ToString()`: omit zero-count severities; append the corrected/correctable/unresolved clause only when `FixMode` is not `Off`, labeling with whichever of corrected or correctable is in play:
  - Apply (in-memory): `1 finding (1 information; 1 corrected, 0 unresolved) across 1 target in 112 ms`
  - Preview: `1 finding (1 information; 1 correctable, 0 unresolved) across 1 target in 112 ms`
  - Off: `3 findings (1 error, 2 warnings) across 2 targets in 90 ms`

## Phase 4 — Documentation and tests

- Docs: `AutoCorrection.md` (result model, selection policy, migration table additions), `MaintainerNotes.md` (summary/severity semantics, applied vocabulary), `CONTEXT.md` prose below the glossary (committed → applied, change-set mentions), `RulePackages.md` touchpoints. `SimplifyResolveCorrection.md` remains historical.
- Tests: update affected suites (correction construction, resolver selection/conflicts, result constructor validation, formatters, `Start-Nitpicking` fix/structural/summary suites). New coverage: multi-edit container round-trip, at-most-one-Safe skip policy, in-memory applied counting, Preview correctable counting, declined-write correctable+unresolved coexistence, ToString variants.
- Validation order: targeted suites for changed files first, then the full Nitpick suite via the repository test runner.

## Non-goals

- Alternative-fix selection (interactive or ranked); `FixMode Guided` remains reserved.
- Changing `-ErrorOn` threshold semantics.
- A PSSA adapter or richer `ToDiagnosticRecord` fidelity (see ADR 0001).
