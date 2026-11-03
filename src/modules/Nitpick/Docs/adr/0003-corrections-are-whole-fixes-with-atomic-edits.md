---
status: accepted
---

# Corrections Are Whole Fixes with Atomic Edits, Not PSSA-Style Suggestions

Nitpick originally borrowed the shape of PSScriptAnalyzer's `SuggestedCorrections`, where multiple corrections on a diagnostic are alternative suggestions surfaced to an editor and never applied by the analysis engine. Nitpick's engine consumes corrections automatically: safe corrections for a target are queued into one AstEditor transaction, rendered against the original snapshot in a single pass, validated as a batch (overlap conflicts and stale text reject the whole target), and saved transactionally per target before the next target is processed.

Under that model, "one record per edit with a stringly `ChangeSetId` grouping" forced every downstream component to re-derive which edits formed one logical fix, and made alternative fixes structurally impossible — two alternatives would both be selected, overlap, and reject the entire target batch.

We decided a `NitpickCorrection` is one complete fix for a finding, containing the text edits that realize it, applied all-or-nothing. It is not an individual edit, and a finding's corrections collection is not an engine-applied worklist of fragments. This follows the layering used by LSP (`CodeAction` containing a `WorkspaceEdit` of many `TextEdit`s), ESLint (one auto-applicable `fix`, separate never-auto-applied `suggestions`), and Roslyn (`CodeAction`s per diagnostic): the fix is the unit of choice; the edit is the unit of application.

## Consequences

- The `ChangeSetId` grouping mechanism is retired from the rule-author API; a correction's edits array is the atomic group. Rule authors build one correction per logical fix.

- The per-target transactional application pipeline (atomic queueing, single-pass render, batch validation, transactional save) is retained unchanged at the AstEditor layer.

- Diagnostic conversion to PSScriptAnalyzer can faithfully export only single-edit corrections; multi-edit corrections are dropped at that boundary because PSSA cannot enforce all-or-nothing application. This is a known, accepted interop cost, consistent with [ADR 0001](./0001-defer-scriptanalyzer-adapter.md).

- Multiple corrections on one finding become the structural slot for future alternative fixes (editor-surfaced), without committing to that feature now.
