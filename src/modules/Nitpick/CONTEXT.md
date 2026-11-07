# Nitpick

Nitpick is this repository's PowerShell linting/autocorrection engine: rule authors contribute checks that inspect parsed script ASTs, and a coordinator selects, executes, and attributes them consistently regardless of where a rule's backing code lives.

## Language

**Rule**:
A single check, backed by either a PowerShell command or a scriptblock, that inspects a Target and reports findings.
_Avoid_: Check, linter, analyzer (reserve "analyzer" for PSScriptAnalyzer specifically)

**Coordinator**:
Nitpick's own orchestration layer (discovery, registration, selection, and execution) that owns a rule's identity. The coordinator assigns identity; a rule's own code never supplies or overrides it.
_Avoid_: Engine, runner

**Producer**:
A rule's own callable body (the function or scriptblock an author writes) that generates findings and corrections. A producer never determines its own identity; it only supplies finding content (message, severity, corrections).
_Avoid_: Rule author's code (reserve "callable" for the underlying PowerShell object itself)

**Namespace**:
A rule's logical owner; its qualifier is the owning module's name even when the rule is implemented in a supporting module. Use `Local` for a rule registered without an owning module.
_Avoid_: Package name, implementation module (when used as the rule's identity)

**Local Name**:
A rule's canonical identifier within its namespace (for example `UseIsNotOperator`), assigned once by the coordinator at discovery or registration time. The descriptor retains it as `Name`; native findings and corrections carry only the qualified `RuleId`. Diagnostic conversion derives external `RuleName` and `RuleSuppressionID` fields from this local component. Renames have no compatibility alias.
_Avoid_: Display name, suppression ID (as if these were separate from Local Name)

**Rule ID**:
A rule's fully qualified identity: `Namespace/Local Name` (for example `WPF/AvoidBlockingUI`). Used for selection, the registry key, and conflict/attribution across native findings.
_Avoid_: Qualified name, full name

### Analysis input

**Target**:
The unit of analysis the user submitted: a file (via `-Path`) or a fragment (via
`-Script`). Findings, corrections, and effective text are always about the target.
_Avoid_: Input, script, source

**Fragment**:
A target that is a scriptblock or AST node taken from a larger body of source — a block
in a file, a block typed at the console, or text created in memory. A fragment is never
written back.
_Avoid_: Scope, nested block, in-memory input

**Snapshot**:
The complete source text a target was parsed from, captured once at analysis time. All
coordinates (findings, edits, diffs) refer to the snapshot. For a file target the
snapshot is the file; for a fragment it is the fragment's host source, which may be
larger than the fragment itself.
_Avoid_: Full script, whole file, original text

**Effective text**:
The target's text after correction handling — the file contents for a file target, or
the fragment's own slice of the rendered snapshot for a fragment. Never the whole
snapshot of a fragment.
_Avoid_: Candidate text (for what is returned to the user), rendered text

### Suppression

**Directive**:
A recognized Nitpick instruction in a source comment.
_Avoid_: Attribute, invocation option

**Whole-target suppression**:
Exclusion of matching rules throughout the submitted target, without changing
invocation-wide rule selection or other targets. The coordinator enforces it;
producers remain suppression-unaware.
_Avoid_: Excluded package, protected edit range

### Correction lifecycle

**Correction**:
One possible fix for a finding: the complete set of text edits that together realize it.
A correction's edits apply all-or-nothing. A finding may carry more than one correction,
but each correction stands alone; corrections are never merged or partially applied.
_Avoid_: Change set, suggested correction, edit (for the whole fix)

**Text Edit**:
A single contiguous text replacement inside a correction, computed against the analyzed
snapshot. The smallest unit of application; never selected or reported independently of
its correction.
_Avoid_: Correction (for an individual replacement)

**Accepted**:
A correction the proposal stage selected for application after policy and validation
checks. A rejected candidate is skipped, with a recorded reason; corrections are never
silently rejected. Alternatives on a finding that were not chosen are neither accepted
nor skipped: they are other ways to resolve the same finding, not separate outcomes.
_Avoid_: Queued, chosen

**Applied**:
An accepted correction whose edits took effect in the effective text — persisted for
file targets, or realized in the returned effective text for fragments.
_Avoid_: Committed, fixed

**Detected (finding)**:
A finding produced by analyzing the original snapshot of a target, before any
correction handling.
_Avoid_: Raw finding, initial finding

**Corrected (finding)**:
A detected finding with at least one applied correction. Corrected means its fix took
effect, not that the problem is proven gone.
_Avoid_: Resolved, fixed

**Correctable (finding)**:
A detected finding with at least one accepted correction that was not applied — a
proposed fix exists but the target is unchanged (preview, WhatIf, declined, or failed
write).
_Avoid_: Fixable, pending

**Undecided (finding)**:
A detected finding whose corrections require a choice that automatic selection never
makes: several Safe alternatives, or only non-Safe corrections. Its corrections are
skipped with a reason and the summary points at Guided mode. A finding the user skipped
during guided selection is not undecided; the choice was made.
_Avoid_: Ambiguous, deferred, needs review

**Skipped (finding)**:
A detected finding with corrections, none of which was accepted, that is not undecided:
stale text, a conflict, an invalid edit, a render failure, or a guided skip. Counts and
summaries use this finding-level resolution; `SkippedCorrections` remains the
correction-level diagnostic record with reasons. A finding with corrections resolves
exactly one way: accepted, undecided, or skipped.
_Avoid_: Rejected (reserved for the proposal status), dropped

**Guided selection**:
Delegating an undecided finding's choice to a `CorrectionSelector`. The correction it
returns is accepted as explicit consent, regardless of applicability; the alternatives
simply go unchosen. The resolver never performs host interaction;
`-FixMode Guided` supplies a selector that navigates with Editor Services and prompts.
_Avoid_: Interactive mode (for the resolver), confirmation

**Unresolved (finding)**:
A finding still present in the effective analysis after correction handling; the input
to severity thresholds. Corrected and unresolved can overlap and need not sum to detected.
_Avoid_: Remaining

### Native identity

`RuleId` is the single native rule identity. Native `RuleName` and `RuleSuppressionID`
fields and helper parameters have been removed. Findings require qualified identity at
construction, including within producers. Detached corrections may omit identity until
coordinated execution. No namespace is inferred. Diagnostic compatibility fields exist
only on external DiagnosticRecords. For the historical migration, see
[Phase 5](Docs/RulePackages.md#phase-5-findings-corrections-and-coordinator-owned-identity).

### Identity boundaries

Coordinated rule execution unconditionally assigns the executing descriptor's identity,
including `Local/Name` for locally owned rules. Producer-supplied attribution is replaced, not validated against the callable's implementing module; implementation and ownership
can differ.

Nitpick assigns its parser findings `Nitpick/PowerShellParseError`. An owned diagnostic
ID does not imply a discoverable/selectable rule or a registry entry.

Standalone producer/helper invocation bypasses coordinated attribution. Helpers accept
an explicit `RuleId` in `Namespace/Name` form and validate its segments with the same
rules as descriptor identity. Removed legacy identity parameters no longer bind, and
constructors reject unknown hashtable keys.
Finding identity does not implicitly stamp nested corrections outside coordinated
execution; callers can supply each correction's identity explicitly.

Display uses `RuleId` without a local-name fallback; unattributed detached corrections
render as `unattributed` in conflict and skipped-correction diagnostics. Built-in
native producers supply explicit `Nitpick/...` IDs for standalone
findings and corrections, and the WPF supporting-module producer supplies
`WPF/AvoidBlockingUI`. These standalone IDs never override coordinated ownership.

## Correction lifecycle ownership

| Component | Owns | Must not do |
| --- | --- | --- |
| [Correction resolver](Public/Interface/Resolve-NitpickCorrectionProposal.ps1) | Selection policy, candidate validation and analysis, proposal diagnostics | Save files, choose effective reporting, or interact with the host |
| [Guided selector](Private/Select-NitpickGuidedCorrection.ps1) | Editor navigation and the correction prompt for one undecided finding | Decide eligibility, record skips, or save files |
| [Target coordinator](Private/Resolve-NitpickTargetCorrection.ps1) | ShouldProcess, application policy, effective report selection, supplying the selector for Guided | Rewrite proposal facts or update invocation totals |
| [Invocation coordinator](Public/Interface/Start-Nitpicking.ps1) | Output, error emission, summaries, severity thresholds | Redo correction selection or reinterpret candidate validity |
| [Result constructor](Public/Helpers/New-NitpickCorrectionResult.ps1) | Envelope shape and lifecycle consistency checks | Repair contradictions, resolve corrections, or perform I/O |
| [AstEditor](../AstEditor/README.md) | Edit validation and transactional persistence | Decide Nitpick selection or reporting policy |

The resolver delegates edit-range, stale-text, conflict, and parsing checks to
AstEditor; it owns the Nitpick policy applied to those results, not a second source
validation implementation.

`Resolve-NitpickCorrectionProposal` returns a `NitpickCorrectionProposal`.
`New-NitpickCorrectionResult` constructs a `NitpickCorrectionResult` with typed
`NitpickCorrectionApplication` and `NitpickCorrectionReport` groups. The result
constructor's Proposal parameter and both text formatters' CorrectionResult parameters
enforce these class contracts. OutputType declarations use string class names because
the classes are defined in the separately parsed root module.

Proposal diagnostics are stable by ownership, not enforced immutability.
`Proposal.Document` is a mutable transaction handle containing the queued edits.
Consumers must not modify its edits between resolution and application. Application
must save that same transaction, not rebuild it from diagnostic fields. A failed or
declined write does not undo candidate reanalysis or change accepted corrections into skips.

`Report.AnalysisSource` identifies the source analyzed by `EffectiveFindings`, not
necessarily the source of `EffectiveText`. Without reanalysis, a valid candidate can
be returned as text alongside original findings. `None` means no analysis, text, or
findings; a read failure has no proposal. Original analysis always refers to the
captured snapshot, not a fresh read of potentially changed disk contents.

The constructor rejects invalid status values, unsupported candidate reporting,
unproven applications, and contradictory read failures. It does not freeze the
result or independently rerun analysis or persistence to verify its evidence.
Do not add top-level aliases or secondary flags that duplicate the owning groups.
