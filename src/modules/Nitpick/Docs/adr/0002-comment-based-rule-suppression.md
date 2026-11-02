---
status: proposed
---

# Coordinator-Owned Comment-Based Rule Suppression

## Status and scope

This is a draft for review, not an accepted decision or an implemented feature.
The syntax and policies below are recommendations. Native comment-based suppression
is currently unimplemented, as recorded in [ADR 0001](0001-defer-scriptanalyzer-adapter.md).

Add suppression for individual source targets analyzed through Nitpick, including
file-backed and in-memory inputs. Do not change invocation-wide rule selection,
producer signatures, or PSScriptAnalyzer-hosted suppression.

## Context

The [domain model](../../CONTEXT.md) assigns rule identity to the coordinator.
`NitpickRule.Invoke` stamps native findings and corrections after producer execution.
The implementing module and owning namespace can differ, so a producer cannot reliably
match a directive against its own qualified Rule ID.

[Start-Nitpicking](../../Public/Interface/Start-Nitpicking.ps1) selects rules before
reading targets, then checks path applicability and invokes rules for each target.
Its AstEditor document already contains parser tokens, including comments.
[Correction proposal resolution](../../Public/Interface/Resolve-NitpickCorrectionProposal.ps1)
also invokes rules against rendered candidate text. Suppression must work in both
analysis paths, before findings affect corrections, reporting, or severity thresholds.

## Proposed decision

The coordinator owns directive parsing, rule matching, and suppression enforcement
for every scope. Producers remain suppression-unaware.

- A whole-target exclusion can skip producer invocation for that target.
- Regional and line suppression filter findings after coordinator-owned attribution.
- Suppression matches qualified Rule IDs, not `RuleName`, `RuleSuppressionID`, command
  names, or a producer's implementing module.
- Shared private helpers serve original analysis and candidate reanalysis. This does
  not require a new public API or a suppression class.

Passing suppression information through `Context` for producer-side optimization is
deferred. It would not replace coordinator enforcement.

## Terminology

**Directive**: A recognized Nitpick instruction in a source comment.

**Suppression**: Exclusion of an otherwise reportable finding through a directive,
including removal of that finding's corrections from automatic selection.

**Whole-target suppression**: Suppression covering the complete analyzed source input.
For a file input, this is file-wide; it does not affect other files in the invocation.

## Proposed syntax

```powershell
# nitpick disable-file Nitpick/AvoidParameterAttributeBool -- Intentional test fixture.

# nitpick disable Nitpick/UseIsNotOperator
if (-not ($Value -is [int])) { }
# nitpick enable Nitpick/UseIsNotOperator

if (-not ($Other -is [int])) { } # nitpick disable-line Nitpick/UseIsNotOperator

# nitpick disable-next-line Nitpick/UseIsNotOperator
if (-not ($Third -is [int])) { }
```

The examples illustrate directives independently; `disable-file` is not a prerequisite
for the other forms.

| Action | Placement | Effect |
| --- | --- | --- |
| `disable-file` | Standalone comment in the leading comment/whitespace preamble | Suppresses matching rules throughout the target |
| `disable` | Standalone comment | Disables matching rules beginning on the next physical line |
| `enable` | Standalone comment | Enables matching rules beginning on the next physical line |
| `disable-line` | Standalone or trailing comment | Suppresses findings starting on that physical line |
| `disable-next-line` | Standalone comment | Suppresses findings starting on the immediately following physical line |

### Grammar and recognition

- Initially support only single-line `#` comment tokens. Block-comment directives,
  including directives embedded in comment-based help, are out of scope.
- After `#` and optional whitespace, require the `nitpick` marker, an action, and at
  least one selector. Marker and action matching are case-insensitive.
- Selectors are separated by whitespace or commas. Empty comma-separated entries
  are malformed. An optional whitespace-delimited `--` begins a free-text reason.
- Accept qualified selectors such as `Nitpick/UseIsNotOperator`, `WPF/*`, and
  `*/AvoidBlockingUI`, plus the explicit all-rules selector `*`.
  Other bare local names and command names are invalid.
- Selector comparison uses the same case-insensitive PowerShell wildcard semantics
  as `IncludeRule` and `ExcludeRule`; reuse the matching mechanism rather than
  introducing a second pattern language.
- A standalone directive has only whitespace before its comment token on that line.
  A misplaced directive is malformed, not an implicit change of scope.
- For `disable-file`, preceding comments, a shebang, and whitespace are allowed.
  A preceding non-comment, non-newline source token ends the preamble.
- Ordinary comments not beginning with the `nitpick` marker are ignored.
  Matching-looking text in strings or here-strings is not a directive.
- Discover actual comment tokens inside expandable-string subexpressions through
  nested tokens where necessary. Do not interpret literal string content as comments.

### Scope and precedence

Whole-target suppression is unconditional for that target. `enable` cannot override
`disable-file` or invocation-level `ExcludeRule`.

For each Rule ID, regional state starts enabled. Process regional directives in source
order: the last preceding matching `disable` or `enable` determines regional state.
This is not a stack; repeated disables do not require balanced enables. An unmatched
enable is a no-op, and an unclosed disable extends to the end of the target.

Evaluate wildcard selectors against the finding's executing Rule ID. For example,
`disable *` followed by `enable Nitpick/UseIsNotOperator` enables that rule while
leaving other rules disabled.

Line suppression adds to whole-target and regional suppression; it never enables a
rule. `disable-next-line` means the next physical line, even if it is blank or a
comment. It does not seek the next statement.

Use the finding's `ViolationExtent.StartLineNumber` as its anchor. A multiline finding
is not suppressed merely because another part of its extent overlaps a suppressed
line. Directives are textual, not lexically scoped: function and scriptblock
boundaries do not reset regional state.

## Selection, diagnostics, and reporting

Keep invocation-wide discovery, registration, literal selector validation, editor
filtering, and path applicability unchanged. Source comments are evaluated only after
the target is read. They cannot acquire rules, undo exclusions, or make invalid
invocation selection succeed.

An eligible rule suppressed by `disable-file` need not execute for that target.
All eligible rules being suppressed in one target is a successful no-findings result,
not the existing invocation-level "no eligible rules" error.

Unmatched but syntactically valid directive selectors are allowed, consistent with
`ExcludeRule`. This supports shared files analyzed with different package selections;
it also means unknown rule names are not detected as typos in this first version.

Malformed recognized directives produce a Warning finding owned by
`Nitpick/InvalidSuppressionDirective`, located at the comment extent. Ignore the
malformed directive as a whole; do not partially apply its selectors. This diagnostic
does not create a selectable rule.

Neither directive diagnostics nor `Nitpick/PowerShellParseError` findings are
comment-suppressible, even under `*`. They remain subject to normal reporting and
`ErrorOn` thresholds. Only attributed native rule findings participate in suppression;
do not infer qualified identity from standalone findings or external DiagnosticRecords.
The existing deferred adapter boundary remains unchanged.

Suppressed rule findings do not contribute to normal output, finding/severity totals,
or `ErrorOn` thresholds. Preserve the existing meaning of `Summary.RuleCount` as the
invocation-selected rule count, not a per-target execution count.

Defer a public suppressed-findings collection, a suppression summary counter, unused
directive detection, and a switch to ignore suppressions. A skipped whole-target rule
has no generated findings to count; reporting a precise suppressed-finding total
would require executing it and would defeat that optimization.

## Corrections and candidate reanalysis

Suppression must prevent correction selection, not merely hide the final diagnostic.
There are two important constraints.

### Preserve complete change sets

`ChangeSetId` is target-wide and can intentionally couple corrections from multiple
findings or rules. Filtering suppressed findings before collecting their change-set
membership would allow an incomplete change set to be applied.

Retain enough original finding/correction membership to mark every change set touched
by a suppressed finding as ineligible. Skip the entire change set, including members
attached to unsuppressed findings, with an explicit suppression reason in proposal
diagnostics. Ungrouped corrections on suppressed findings are simply not selected.
Do not mutate producer-owned correction arrays to accomplish filtering.

Unsuppressed findings remain reportable even when a shared change set is blocked.
Suppression does not introduce a new application status or transfer correction policy
out of the resolver. The exact internal handoff of blocked change-set membership must
be designed with the existing resolver inputs during implementation.

Suppression is not an edit-protection mechanism: an unsuppressed finding can propose
an edit spanning a suppressed line. Do not add correction-range suppression implicitly;
that would be a separate policy.

### Recompute against the analyzed snapshot

Extract directives again from rendered candidate text before candidate rule execution
and filtering. Do not reuse original line numbers: corrections can move or remove
comments. Reevaluate whole-target exclusions using the candidate's directives.

Retain the path-applicable, invocation-selected descriptors for candidate analysis,
including descriptors skipped only because of original whole-target suppression.
Otherwise a candidate that removes a file directive could never reenable those rules.

Both `OriginalFindings` and `CandidateFindings` exposed by the proposal must use their
own snapshot's suppression decisions. Preserve the existing effective-report policy
for Preview, Apply, WhatIf, declined writes, and failed writes; do not rewrite proposal
facts when the application outcome selects original rather than candidate reporting.

Direct calls to the public correction resolver need the same suppression policy for
qualified native inputs and candidate analysis. Standalone findings without Rule ID
remain outside identity-based matching; no namespace is invented for them.

## Source-coordinate requirement

For file-backed inputs, document tokens and findings normally share coordinates.
For in-memory AST inputs, ordinary lint currently retains the supplied AST's original
extent context, while AstEditor reparses `Extent.Text` into document-relative coordinates.
Nested or extracted ASTs can therefore have nonzero original line, column, and offset
origins.

Directive matching must explicitly map into the finding's coordinate space, or compare
through a shared source-relative representation. Do not reparse and replace the original
AST merely to align lines: that would change existing finding locations. Whole-target
suppression refers only to the analyzed input, not comments outside a supplied nested
AST's extent.

## Implementation outline

1. Add private token-based directive parsing and shared Rule ID/location matching.
2. Wire original target analysis to whole-target gating and finding suppression,
   retaining correction membership needed to block complete change sets.
3. Extend correction selection and candidate analysis to apply the same policy.
   Keep persistence in AstEditor and application/report selection in their existing owners.
4. Add focused parser, coordinator, correction, and coordinate contract tests.
5. Once accepted and implemented, update the README, domain terminology, maintainer
   identity notes, and correction documentation. Clarify that legacy local-name
   `RuleSuppressionID` compatibility is distinct from native qualified-ID directives.

No producer changes or dependency additions are expected. Exact helper names and
internal result shapes are implementation details, not decisions of this ADR.

## Required verification

- Each action, placement rule, comma/whitespace selector list, and optional reason.
- Case-insensitive qualified selectors, wildcards, same local names across namespaces,
  and ownership differing from the implementing module.
- Regional precedence, repeated disables, unmatched enables, EOF, and physical-line
  behavior across blank lines, multiline findings, and nested scriptblocks.
- No directives from literal strings, here-strings, or block comments; actual nested
  comment tokens are handled deliberately.
- Malformed directives remain visible, unknown selectors are allowed, and parser
  findings cannot be suppressed.
- Multiple files stay independent; whole-target suppression skips producer invocation;
  all rules suppressed in a target succeeds without bypassing invocation validation.
- Object/text output and severity totals exclude suppressed findings without changing
  selected-rule totals.
- Suppressed corrections never apply. A mixed suppressed/unsuppressed change set,
  including one shared across rules, is skipped atomically.
- Candidate edits moving/removing directives, candidate re-enablement, original versus
  candidate reports, WhatIf, declined/failed writes, and direct resolver calls.
- File inputs, string inputs, and nested AST inputs retain correct directive matching
  and existing finding locations, including CRLF and LF source text.
- No-directive inputs preserve existing results. Follow the repository test runner and
  retain Windows PowerShell 5.1 compatibility.

## Alternatives and consequences

**Producer-owned line suppression** would require every producer to participate and
would match before coordinator identity is assigned. Reject it as the enforcement
boundary; optional producer optimization remains a possible later enhancement.

**Output-only filtering** is simpler but can silently apply corrections for hidden
findings. Reject it.

**Treating a leading `disable` as file-wide** avoids a separate action but makes
placement determine whether the producer executes. Prefer explicit `disable-file`,
reserving `disable`/`enable` for ordered regional state.

The proposed design centralizes correctness without changing rule-authoring contracts.
It adds shared analysis policy and a correction-selection handoff, rather than only a
text filter. Line-based anchors are predictable but cannot distinguish two findings
from the same rule starting on the same line.

## Review decisions still open

- Accept the explicit `disable-file` form and its leading-preamble restriction, or
  prefer a different whole-target syntax.
- Accept start-line anchoring and physical next-line behavior rather than
  statement-aware or extent-overlap suppression.
- Accept non-stacking regional state and unconditional whole-target exclusions.
- Accept Warning findings for malformed directives, optional reasons, and
  initially deferring block-comment directives and unused-directive reporting.
