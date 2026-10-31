# Nitpick

Nitpick is this repository's PowerShell linting/autocorrection engine: rule authors contribute
checks that inspect parsed script ASTs, and a coordinator selects, executes, and attributes
them consistently regardless of where a rule's backing code lives.

## Language

**Rule**:
A single check, backed by either a PowerShell command or a scriptblock, that inspects a
ScriptBlockAst and reports findings.
_Avoid_: Check, linter, analyzer (reserve "analyzer" for PSScriptAnalyzer specifically)

**Coordinator**:
Nitpick's own orchestration layer (discovery, registration, selection, and execution) that
owns a rule's identity. The coordinator assigns identity; a rule's own code never supplies
or overrides it.
_Avoid_: Engine, runner

**Producer**:
A rule's own callable body (the function or scriptblock an author writes) that generates
findings and corrections. A producer never determines its own identity; it only supplies
finding content (message, severity, corrections).
_Avoid_: Rule author's code (reserve "callable" for the underlying PowerShell object itself)

**Namespace**:
A rule's logical owner; its qualifier is the owning module's name even when the rule is
implemented in a supporting module. Use `Local` for a rule registered without an owning module.
_Avoid_: Package name, implementation module (when used as the rule's identity)

**Local Name**:
A rule's canonical identifier within its namespace (for example `UseIsNotOperator`), assigned
once by the coordinator at discovery or registration time. The `RuleName` and
`RuleSuppressionID` properties on a finding both carry this exact value — they are not
independent, producer-supplied identities, and a rename of a rule's backing command or
registration changes both at once with no compatibility alias.
_Avoid_: Display name, suppression ID (as if these were separate from Local Name)

**Rule ID**:
A rule's fully qualified identity: `Namespace/Local Name` (for example `WPF/AvoidBlockingUI`).
Used for selection, the registry key, and conflict/attribution across native findings.
_Avoid_: Qualified name, full name

### Identity direction

Long term, `RuleId` is the rule name and the single rule identity. The separate
`RuleName` and `RuleSuppressionID` finding fields are transitional compatibility
fields, not independent identities to extend. Phase 5 retains them while establishing
coordinator-owned qualified attribution; it does not add a suppression field to corrections.
Their eventual removal requires an explicit migration of helper signatures, standalone
invocation, diagnostic conversion, and suppression behavior. See
[Phase 5](Docs/RulePackages.md#phase-5-findings-corrections-and-coordinator-owned-identity).

### Identity boundaries

Coordinated rule execution unconditionally assigns the executing descriptor's identity,
including `Local/Name` for locally owned rules. Producer-supplied attribution is replaced,
not validated against the callable's implementing module; implementation and ownership
can differ.

Nitpick assigns its parser findings `Nitpick/PowerShellParseError`. An owned diagnostic
ID does not imply a discoverable/selectable rule or a registry entry.

Standalone producer/helper invocation bypasses coordinated attribution. In Phase 5,
display the supplied `RuleName` when `RuleId` is absent without inventing a namespace.
This display fallback does not establish identity and must not conceal missing stamping
in coordinated execution. An explicit standalone `RuleId` input API is deferred to the
later helper-signature migration.

## Correction lifecycle ownership

| Component | Owns | Must not do |
| --- | --- | --- |
| [Correction resolver](Public/Interface/Resolve-NitpickCorrectionProposal.ps1) | Selection policy, candidate validation and analysis, proposal diagnostics | Save files or choose effective reporting |
| [Target coordinator](Private/Resolve-NitpickTargetCorrection.ps1) | ShouldProcess, application policy, effective report selection | Rewrite proposal facts or update invocation totals |
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
declined write does not undo candidate reanalysis or change accepted edits into skips.

`Report.AnalysisSource` identifies the source analyzed by `EffectiveFindings`, not
necessarily the source of `EffectiveText`. Without reanalysis, a valid candidate can
be returned as text alongside original findings. `None` means no analysis, text, or
findings; a read failure has no proposal. Original analysis always refers to the
captured snapshot, not a fresh read of potentially changed disk contents.

The constructor rejects invalid status values, unsupported candidate reporting,
unproven commitments, and contradictory read failures. It does not freeze the
result or independently rerun analysis or persistence to verify its evidence.
Do not add top-level aliases or secondary flags that duplicate the owning groups.
