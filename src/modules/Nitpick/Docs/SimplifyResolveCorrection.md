# Redesign target correction orchestration

## Goal and scope

Replace the mixed correction-result contract with a stable proposal, a separate
application outcome, and an explicit reporting policy. Simplify
[Resolve-NitpickTargetCorrection](../Private/Resolve-NitpickTargetCorrection.ps1)
by removing the need to rewrite proposal facts after persistence decisions.

Breaking changes are acceptable while Nitpick is in early development. This plan
supersedes the behavior-preserving refactor: migrate consumers directly rather than
introducing compatibility aliases or maintaining both contracts.

Keep the scope within Nitpick's correction lifecycle and result consumers. Do not
redesign rule-author APIs, finding production, correction coordinates, applicability,
change sets, rule discovery, or AstEditor persistence. Preserve their existing safety
guarantees.

## 1. Define the new contract

Keep one `Nitpick.CorrectionResult` envelope per target in correction-mode output.
Separate its information into three groups:

```text
CorrectionResult
  Path
  Proposal
    Path
    Document
    OriginalFingerprint
    Status
    OriginalText
    OriginalFindings
    CandidateText
    CandidateFindings
    WasReanalyzed
    AcceptedCorrections
    SkippedCorrections
    Conflicts
    ParseErrors
    Diff
  Application
    Status
    CommittedCorrections
    WriteResult
    ErrorRecord
  Report
    AnalysisSource
    EffectiveText
    EffectiveFindings
    FindingsWithCommittedCorrections
```

Use this as the baseline schema. Finalize exact status values and diagnostic
placement in contract tests before implementation, using existing AstEditor
outcomes rather than inventing a parallel write-error taxonomy.

### Ownership and invariants

- The resolver owns the proposal. Application and reporting do not mutate it.
- `AcceptedCorrections` means selected edits that passed candidate validation.
- `SkippedCorrections` describes resolution decisions, not persistence failures.
- `WasReanalyzed` records whether candidate reanalysis actually happened. It stays
  true after a declined or failed write if reanalysis occurred.
- An empty candidate finding array can mean successful analysis with no findings.
  Use `WasReanalyzed`, not array length, to distinguish it from unavailable analysis.
- Candidate text and diagnostics remain available even if validation or writing
  fails. Availability of candidate text does not imply it is valid.
- The application owns persistence outcomes. Only a successful write populates
  `CommittedCorrections`.
- The report owns the choice of effective analysis. `AnalysisSource` explicitly
  identifies original versus candidate findings.
- Arrays are always arrays, including empty and singleton collections. Absent
  optional records are null.

The proposal need not be a technically immutable PowerShell object. The requirement
is clear ownership and no mutation by later lifecycle stages. Avoid class hierarchies,
generic state-machine frameworks, and helpers that merely wrap property assignments.

### Read failures and calls without Fix

A read failure occurs before resolution: return an envelope with `Proposal = $null`,
an explicit `FailedRead` application outcome and error, and an empty report with no
analysis source. Do not fabricate a successful empty proposal or original analysis.
The caller must report the error and count the failed target.

Without `Fix`, preserve ordinary lint output and do not emit a correction envelope.

### Intentional breaking changes

- Replace the flat, overloaded `WriteStatus` with proposal and application statuses.
- Replace `Findings.Final` and `Findings.Remaining` with one
  `Report.EffectiveFindings` collection.
- Replace `Findings.Fixed` with `Report.FindingsWithCommittedCorrections`.
- Replace `Corrections.Fixed` with `Application.CommittedCorrections`.
- Do not convert accepted corrections into skipped corrections when a write fails.
- Remove duplicated top-level flags and fields where their owning group already
  expresses the fact; do not retain legacy aliases.

Findings with committed corrections are not necessarily fully resolved. Do not
infer which original findings disappeared without a reliable identity mechanism.
Other finding classifications should be retained only where consumers need them,
derived from proposal facts, and allowed to overlap.

## 2. Specify reporting and application behavior

Define the following outcome matrix in tests before rewriting orchestration:

| Situation | Application behavior | Effective report |
| --- | --- | --- |
| No accepted corrections | No write attempt | Original analysis, or valid candidate reanalysis when available |
| In-memory | Return candidate without writing | Valid candidate analysis/text |
| Explicit preview | No write attempt | Valid candidate analysis/text |
| WhatIf | Honor ShouldProcess; no write | Valid candidate analysis/text |
| Confirmation declined | No write | Original analysis/text |
| Successful write | Commit accepted corrections | Valid candidate analysis/text |
| Failed or stale write | Report persistence failure; commit nothing | Original analysis/text |
| Invalid or rejected candidate | No write | Original analysis/text |
| Read failure | Report read error; no proposal or write | No analysis |

Preserve in-memory precedence over preview and WhatIf. Candidate validation failures
must not be relabeled as preview or in-memory success.

When candidate text is valid but reanalysis was not requested, keep effective
findings from the original analysis, record that source explicitly, and expose
candidate text where the outcome permits it. Do not imply those findings analyze
the candidate text.

Original analysis after a stale-write failure refers to the captured snapshot,
not a fresh analysis of externally changed disk contents.

## 3. Separate resolution, application, and reporting

### Resolution

Change [Resolve-NitpickCorrection](../Public/Interface/Resolve-NitpickCorrection.ps1)
to return the proposal contract directly. Preserve selection, conflict detection,
change-set atomicity, validation, and caller-selected reanalysis.

### Application and orchestration

Make [Resolve-NitpickTargetCorrection](../Private/Resolve-NitpickTargetCorrection.ps1)
a linear coordinator:

```text
Resolve proposal
Determine application outcome and save only when permitted
Select effective reporting data
Return completed envelope
```

Keep `ShouldProcess` at this orchestration boundary. Preserve confirmation behavior
and prevent duplicate prompts from the underlying save operation. Keep persistence
in `Save-AstDocument`; do not modify AstEditor's transaction machinery.

Select effective findings and text once. Do not temporarily replace proposal
properties and then restore them on failure.

Update [New-NitpickCorrectionResult](../Public/Helpers/New-NitpickCorrectionResult.ps1)
for the new envelope. Add a proposal constructor only if shared construction or
schema validation warrants it. Remove the old array-only `ConvertTo-NitpickResultGroup`
helper if the new envelope no longer needs it.

## 4. Migrate consumers and accounting

Update [Start-Nitpicking](../Public/Interface/Start-Nitpicking.ps1) to consume the
new envelope for object output, text output, severity thresholds, write errors,
and read failures. Aggregate summary counters there; remove the private helper's
`Summary` parameter.

Make summary meanings explicit:

- Rename `FixedFindingCount` to `FindingsWithCommittedCorrectionsCount`; count each
  original finding once when at least one associated correction was committed.
- `SkippedCorrectionCount` counts proposal-stage skips only. Write failures no
  longer inflate it.
- `ConflictedTargetCount` counts targets with proposal conflicts once per target.
- `FailedTargetCount` counts each failed target once, covering read, validation,
  and persistence failures. Preview, WhatIf, in-memory results, and user declines
  are not failures.
- Ordinary severity counts and thresholds use `Report.EffectiveFindings`.

Preserve existing behavior for conflict-only rejection unless deliberately changed
and tested; do not silently count it as a validation or persistence failure.

Migrate all discovered consumers, not just the primary call path:

- [Module exports](../Nitpick.psd1), if constructor exports change.
- [Performance measurement script](../Scripts/Measure-LinterPerformance.ps1.ps1).
- Resolver, constructor, coordinator, rule, and package contract tests.
- [README](../README.md), [autocorrection documentation](AutoCorrection.md), and
  affected function help.

Repository searches found references within Nitpick, but that is not proof that
external consumers do not exist. Document the breaking schema and summary changes.
Search for old fields again after migration and inspect remaining matches rather
than blindly replacing similarly named properties.

## 5. Implement and validate in coherent stages

1. Define schema, status vocabulary, invariants, and summary semantics in focused
   contract tests.
2. Implement proposal construction and migrate direct resolver consumers.
3. Implement application/report separation and migrate invocation output and
   accounting.
4. Update remaining consumers and documentation; remove obsolete schema code.
5. Run broader regression validation after targeted tests pass.

Load the `pwsh-test-runner` skill before test discovery or execution and use the
repository [test runner](../../../../tools/Invoke-Test.ps1). Start with:

- [Correction-result constructor tests](../Tests/Public/Helpers/New-NitpickCorrectionResult.Tests.ps1).
- [Resolver change-set tests](../Tests/Public/Interface/Resolve-NitpickCorrection.ChangeSets.Tests.ps1).
- [Private target-correction tests](../Tests/Private/Resolve-NitpickTargetCorrection.Tests.ps1).
- [Public fix tests](../Tests/Public/Interface/Start-Nitpicking.Fix.Tests.ps1).
- [Public structural-fix tests](../Tests/Public/Interface/Start-Nitpicking.Structural.Fix.Tests.ps1).

Then cover affected rule/package contracts and other Nitpick regressions. Keep
PowerShell 5.1 compatibility and use existing lint tooling for modified code.

Verify exact behavior, not just status strings:

- Empty/singleton array shapes and null proposal handling.
- No proposal mutation across successful, failed, and declined application paths.
- Reanalysis remains recorded after failed application.
- Candidate diagnostics survive failed validation and persistence.
- No committed corrections on preview, decline, or failure.
- Multi-correction findings are counted once without claiming full resolution.
- Correct summary counts and severity thresholds, including multiple targets.
- Unchanged file bytes on non-write paths and existing atomic-write guarantees.
- Explicit read/write errors and continued processing of independent targets
  unless terminating errors were requested.
- No duplicate confirmation, accidental saves, or leaked invocation state.

## Definition of done

- Proposal facts, application outcomes, and effective reporting have distinct owners.
- The coordinator reads linearly and never rolls back proposal properties.
- The new contract is used consistently by all repository consumers.
- Legacy fields and compatibility aliases are absent.
- Intentional breaking changes are documented and asserted in tests.
- Correction safety, persistence behavior, and unrelated rule APIs remain intact.
- Targeted and appropriate broader validation pass.

Judge success by local reasoning and coherent semantics, not line-count reduction
or the number of new helpers.
