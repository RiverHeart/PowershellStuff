### PowerShell engine quirks worth their own rules

A few language/engine quirks surfaced during the [Rule Packages](Docs/RulePackages.md) Phase 4 work that are easy to reintroduce elsewhere in this repository, and are not currently caught by anything:

- Member-access on a zero-element array (`@($EmptyArray.Property)`) does not enumerate per item
  the way it does for two or more elements; it falls back to a direct property lookup on the
  array itself and yields one `$null`, not zero results. `ForEach-Object { $_.Property }` behaves
  correctly at every count and should be preferred.
- `ForEach-Object <MemberName>` (the single-positional-argument member-name shorthand) itself
  honors `$WhatIfPreference` and silently returns nothing under `-WhatIf`, unlike
  `ForEach-Object { $_.MemberName }`. This is easy to hit whenever that shorthand is used inside
  a `SupportsShouldProcess` command, even far from any actual `ShouldProcess` call.
- `Select-Object -First`/`-Last` leaks a spurious `StopUpstreamCommandsException` into a caller's
  `-ErrorVariable` on Windows PowerShell 5.1 whenever that caller also specifies `-ErrorAction`
  (any value, not just `Stop`). This one stayed latent in the Phase 2 module resolvers for an
  entire session; it only surfaced once Phase 4 made that code path universally reachable.

## Notes

- ScriptAnalyzer searches for functions named `Measure-*` and `Test-*` so we should be safe to export any helper functions from this module that do not use those verbs.
- ScriptAnalyzer's `PSUseOutputTypeCorrectly` doesn't seem to take strings into account for `[OutputType('CustomClass')]` when the `return` keyword is missing from a `[CustomClass]::new()` output. Is there some metadata exposed by `return` or does the check require `return` and `[OutputType()]` together?

## Native finding identity

Coordinated native findings and corrections carry a qualified `RuleId`, such as
`Nitpick/UseIsNotOperator` or `Local/MyRule`. The executing rule descriptor owns that
identity: it replaces producer-supplied attribution during both original execution and
candidate reanalysis. Ownership follows the declaring package or registration, not
necessarily the module implementing the callable.

Text output, default finding tables, string conversion, and correction diagnostics use
qualified IDs. Native findings and corrections carry only `RuleId`; the legacy
`RuleName` and `RuleSuppressionID` properties and helper parameters have been removed.
Descriptors still retain `Name` and `Namespace` as identity components.
`ToDiagnosticRecord()` validates the current ID and derives both external local-name
fields at conversion time. PSScriptAnalyzer compatibility remains local-name based;
native comment suppression is not yet implemented.

Parser findings use `Nitpick/PowerShellParseError`; that attribution does not create a
selectable rule or registry entry. Direct producer/helper invocation bypasses coordinated
attribution: finding constructors and `New-NitpickFinding` require qualified identity,
while detached corrections may remain unattributed until coordinated execution.
Display never infers a namespace or falls back to a legacy local label; conflict and
skipped-correction diagnostics label unattributed detached corrections `unattributed`.

The helper migration accepts explicit `-RuleId Namespace/Name` on
`New-NitpickFinding` and `New-NitpickCorrection`. Namespace and local-name validation
reuse descriptor identity rules; wildcard IDs are invalid. Removed legacy identity
parameters no longer bind on the helpers. Hashtable constructors reject unknown keys,
including the removed legacy identity fields, even when a valid `RuleId` is also
present. The old positional finding constructor, which
could not supply qualified identity, has been removed.

Built-in native producers use explicit `Nitpick/...` IDs for standalone findings and corrections; WPF's
supporting-module producer uses `WPF/AvoidBlockingUI`, not `WPFRules/AvoidBlockingUI`.
Parser diagnostics also use the qualified helper API rather than assigning `RuleId`
after construction. Existing direct ScriptAnalyzer output retains local diagnostic
names and suppression IDs through conversion.

A standalone finding does not assign identity to its
nested corrections; those can receive explicit IDs separately. Coordinated invocation
still replaces all producer attribution. Direct resolver callers supply qualified
finding identity explicitly; optional detached-correction identity is not inferred
from the parent finding.

Identity is retained across the correction proposal, application, and report without
rewriting proposal facts or splitting a correction's atomic `TextEdits`.

### Proposed native comment suppression

[ADR 0002](adr/0002-comment-based-rule-suppression.md) drafts coordinator-owned
comment suppression using qualified Rule IDs, including whole-target, regional,
and line directives. It covers correction atomicity, candidate reanalysis,
and in-memory source coordinates. The proposal is not yet accepted or implemented;
it does not change the current compatibility behavior described above.

## Autocorrection

Preview safe corrections and view the diff without modifying files:

```powershell
Start-Nitpicking -Path .\Example.ps1 -FixMode Preview
```

Apply the same validated transaction, or preview using standard PowerShell confirmation semantics:

```powershell
Start-Nitpicking -Path .\Example.ps1 -FixMode Apply -Confirm
Start-Nitpicking -Path .\Example.ps1 -FixMode Apply -WhatIf
```

`-FixMode Apply` writes file-backed `-Path` targets unless `-WhatIf` or a declined
confirmation prevents it. `-Script` inputs always return in-memory output. Use `-Output Object`
for a correction envelope with `Proposal`, `Application`, and `Report` groups.
For `-Script` inputs, `-FixMode Preview` reports `Application.Status = 'Preview'` and
proposed corrections; only `-FixMode Apply` reports `InMemory` and corrections applied in
memory. Both modes return candidate text without modifying the supplied input.
Text output groups each target into one section: the target path as a header, its findings,
then a diff of proposed or applied edits. Each correction is labeled by the `line:column` where
it starts, so editors such as VS Code can link it against the header. Bare, uncolored
carets beneath removed and added lines narrow down the queued edit spans without
changing those reason headers. Multiline spans annotate their first line only;
carets show edit ranges, not minimal textual differences. A one-line trailer states
the outcome once, for example `1 proposed correction.` for `-FixMode Preview` and `-WhatIf`, or
`1 correction applied.` after writing. Skipped, conflicting, or failed corrections report full
counts with their proposal and application statuses. It omits the correction section when a target
has no correction activity. Use `-Verbose` for
per-target no-op diagnostics. Text output counts whole corrections, however many edits
each contains. Object output retains the corrections in `Proposal.AcceptedCorrections`
and `Application.AppliedCorrections`.
`Proposal` retains candidate text, reanalysis, skipped corrections, and conflicts regardless
of application outcome. Only `Application.AppliedCorrections` describes applied
corrections — a successful write for file targets or an in-memory apply for script
targets; `Application.Status` records whether writing succeeded, failed, or was not requested.
Summary `FindingCount` and the severity counters describe detected findings from the
original analysis, parse errors included. `-ErrorOn` and `UnresolvedFindingCount` use
`Report.EffectiveFindings`: candidate analysis for previews and successful or in-memory
applies when available, original analysis for failed or declined writes.
`CorrectedFindingCount` counts findings with an applied correction;
`CorrectableFindingCount` counts findings whose accepted corrections were not applied.
`UndecidedFindingCount` counts `Proposal.UndecidedFindings`: findings whose corrections
need a choice automatic selection never makes; outside Guided mode the summary text adds
a hint to use `-FixMode Guided`. `SkippedFindingCount` (formerly `SkippedCorrectionCount`)
counts `Proposal.SkippedFindings`: findings with corrections, none accepted, that are not
undecided. Counts are per finding because a finding's alternative corrections are
different ways to resolve it; `Proposal.SkippedCorrections` keeps the correction-level
reasons for `-Verbose`. `Proposal.SourcePath` records the origin file of a
snapshot with source provenance and is informational; `Proposal.Path` remains the write
target or `<ScriptBlock>`.
Corrected does not mean resolved, and the counters need not sum to `FindingCount`.
`Report.EffectiveText` contains the selected output text. `Report.AnalysisSource`
identifies the source analyzed by `EffectiveFindings`, not necessarily `EffectiveText`:
without reanalysis, valid candidate text can accompany original findings.

Proposal diagnostics are stable by ownership, not enforced immutability.
`Proposal.Document` is the mutable queued transaction; consumers must not change its
edits between resolution and application. The result constructor rejects contradictory
lifecycle states instead of repairing them. See the
[ownership boundaries](CONTEXT.md#correction-lifecycle-ownership) for maintainer responsibilities.

The default `-FixMode Off` performs ordinary linting without emitting a correction result.
Replace the former `-Fix -Preview` switches with `-FixMode Preview`, and `-Fix` with
`-FixMode Apply`.

For direct correction workflows, `Resolve-NitpickCorrectionProposal` replaces
`Resolve-NitpickCorrection` and returns a `NitpickCorrectionProposal`, not a result.
`New-NitpickCorrectionResult` wraps a proposal with application and reporting data.
These are now PowerShell classes defined in the module, including typed
`NitpickCorrectionApplication` and `NitpickCorrectionReport` groups. Their runtime
type names replace the former `Nitpick.CorrectionProposal` and `Nitpick.CorrectionResult`
labels. Update object-output filters accordingly. Helpers work with `Import-Module`;
scripts naming these classes in type literals require `using module` at parse time.
Formatters require a `NitpickCorrectionResult`, so passing a proposal fails at parameter
binding rather than on a missing nested property. Classes preserve the existing mutable
transaction ownership and constructor validation; they do not enforce immutability.

The result contract intentionally breaks the earlier flat schema: use
`Proposal.AcceptedCorrections` instead of `Corrections.Accepted`,
`Application.AppliedCorrections` instead of `Corrections.Fixed`, and
`Report.EffectiveFindings` instead of `Findings.Final` or `Findings.Remaining`.
`Report.FindingsWithAppliedCorrections` attributes applied corrections to original
findings; it does not claim complete resolution. `Report.FindingsWithAcceptedCorrections`
attributes accepted corrections the same way regardless of application outcome. The
summary counters are now `CorrectedFindingCount`, `CorrectableFindingCount`, and
`UnresolvedFindingCount`, replacing `FixedFindingCount`.
Failed writes do not turn valid accepted proposals into skipped corrections.

Files retain encoding, BOM, and existing newline characters through AstEditor's transactional
save. BOM-less input must be valid UTF-8; BOM-marked UTF-8, UTF-16, and UTF-32 are supported.
Byte fingerprints reject changed sources before replacement. Transactions are per target,
so a failed target does not roll back successful changes to another target. Use
`-ErrorAction Stop` to stop on a reported error.

`UseIsNotOperator` offers a native coordinated fix for `-not (<expression> -is <type>)`:
it removes only `-not` and replaces the actual operator with `-isnot`, retaining parentheses
and trivia. Redirected/background type-test pipelines remain diagnostic-only. ScriptAnalyzer
also receives diagnostics only for this rule. Finding conversion omits multi-edit
corrections, since ScriptAnalyzer cannot enforce atomic groups; ungrouped simple suggestions
remain available.

Phase 6 is complete: token-aware coordinated fixes use the existing single-pass
preview, validation, reanalysis, and per-target commit pipeline. No separate provider
framework is required. A correction's `TextEdits` array is its atomic group;
`ChangeSetId` is retired
([ADR 0003](adr/0003-corrections-are-whole-fixes-with-atomic-edits.md)).
Optional multi-pass correction remains proposed.
Token acquisition scaling will be evaluated separately.

See [Nitpick Autocorrection](Docs/AutoCorrection.md) for the implemented contracts,
result schema, safety boundaries, and remaining work.

## Gotchas

For the manifest contract and package ownership behavior, see
[Manifest-Declared Rule Packages](Docs/RulePackages.md).

### Acquiring rule packages

Pass module names or literal module paths to `Find-Nitpick` or `Start-Nitpicking -Module`:

```powershell
Find-Nitpick -Module .\MyRules\MyRules.psd1
Start-Nitpicking -Path .\Example.ps1 -Module .\MyRules\MyRules.psd1 `
    -IncludeRule MyRules/MyRule
```

Replace legacy `-RulePath` or `-RuleModule` arguments with `-Module`. Native
`-IncludeRule`/`-ExcludeRule` selectors now use qualified `Namespace/LocalName` IDs;
bare local names and callable command names are not inferred.

Acquisition is explicit: Nitpick does not scan ambient loaded modules. A module can declare
its own exported rule commands with `PrivateData.Linting.Rules` and compose supporting
modules with `PrivateData.Linting.RuleModules`, using paths relative to the declaring
manifest. A module with no `Linting` declaration can still be acquired directly; Nitpick
then discovers compatible exported `Test-*` and `Measure-*` commands.

A supporting rule module declares its owner with `PrivateData.Linting.OwnerModule`, a
relative path to the owner's manifest. The owner must list that supporting module in
`RuleModules`. Nitpick validates both sides before importing, and uses the owner's module
name as the namespace whether the rule is acquired through the owner or directly. For
example, WPFRules declares WPF as its owner, so both `Find-Nitpick -Module WPF` and direct
acquisition of WPFRules produce `WPF/AvoidBlockingUI`.

Package imports execute module code and may load assemblies or leave other process-level
effects; scoped imports are not an unloading guarantee. Only acquire trusted modules.
The module name `Local` is reserved for module-less registrations and cannot own a package.
Rule declarations currently use command callables; typed AST rule declarations remain
proposed, as described in [Typed AST Rule Dispatch](Docs/TypedAstRuleDispatch.md).

### Discovery versus registration

`Start-Nitpicking` builds an invocation-local rule list without modifying the registry.
Use `Register-Nitpick` explicitly for persistent rules, scriptblock callables, or metadata
overrides such as category and editor enablement. Scriptblock registrations default to
the `Local` namespace; use `-Namespace` when a scriptblock has an explicit owner.
`Get-Nitpick` lists explicit registrations, not package rules acquired for the last
invocation. `Find-Nitpick` acquires the built-in Nitpick package by default; specifying
`-Module` replaces that default unless `-IncludeDefaults` is also passed. In contrast,
`Start-Nitpicking -Module` adds packages alongside built-in rules unless `-ExcludeDefaults`
is specified.

An explicitly registered rule takes precedence over discovery of the same callable,
preserving its metadata and running it only once. Different callables with the same
case-insensitive qualified Rule ID terminate selection before analysis or fixing.
Excluded rules do not participate in conflict checks; editor-mode filtering follows them.
Failed selection does not partially populate the registry.

`Unregister-Nitpick` removes a registration, not a package declaration or exported command.
Use `-ExcludeRule` to prevent an acquired rule from executing.

### Rule selection must succeed before execution

`Start-Nitpicking -IncludeRule` accepts qualified IDs such as
`Nitpick/UseIsNotOperator` and `WPF/AvoidBlockingUI`, not local names or command names
such as `Test-UseIsNotOperator`. Matching is case-insensitive and supports wildcards.
Every literal include selector must match at least one discovered or registered rule;
a valid selector alongside a typo does not permit a partial run. Unmatched selectors
cause a terminating error before targets are read, findings or summaries are emitted,
or fixes are applied. Unmatched wildcard selectors are allowed if at least one eligible
rule remains.

Include selectors are validated before exclusions and editor-mode filtering.
Unmatched exclusions are allowed, but if exclusions or `-EditorMode` leave no eligible
rules, execution terminates with a distinct error. Running with no discoverable or
registered rules also terminates. These selection errors stop execution even without
`-ErrorAction Stop`; `-ErrorOn` remains the separate threshold for emitted findings.

Discovery remains permissive: `Find-Nitpick` may return no matches without error.
Use `Find-Nitpick` to acquire rule descriptors and `Get-Nitpick` to inspect registered
rules and their qualified IDs.

File targets are resolved across all piped `-Path` values before analysis or fixing.
Literal paths must exist; wildcard paths can match nothing. Only files count as targets,
and the complete invocation must retain at least one file after `-Filter`, `-IncludePath`,
and `-ExcludePath`. An empty directory alongside a valid target is allowed.

Literal `-IncludePath` selectors must match a resolved file's full path before exclusions
are applied; unmatched wildcard include filters and unmatched exclusions are allowed.
Relative literal `-Path` values are supported, but `-IncludePath` retains its existing
full-path matching semantics. Path selection errors terminate before findings or summaries
are emitted and before fixes are applied. `-Script` provides an in-memory target and
is not subject to file-path filtering or the file-target requirement. Rule-specific path
scopes remain unchanged; applicability of every rule-target pair is not validated.

### Explicit rule context

Rules can opt into an optional `[System.Collections.IDictionary] $Context` parameter.
`NitpickRule.Invoke($Ast)` supplies `Caller = 'Nitpick'`, the AST's file path in `File`,
and `RuleBehavior` settings for recursive traversal (`SearchNestedScriptBlocks = $true`)
and native output (`OutputType = 'NitpickFinding'`). Initial lint and fix reanalysis use
the same defaults. Callables without a `Context` parameter remain supported.

`Invoke($Ast, $Context)` passes the explicit dictionary unchanged to opted-in rules.
The built-in rules use behavior settings rather than caller identity. Without context,
or with omitted behavior settings, these ScriptAnalyzer-compatible rules search only
the supplied scope and emit `DiagnosticRecord` objects; ScriptAnalyzer visits nested
scopes separately. Direct diagnostic invocations require PSScriptAnalyzer to be loaded.

`New-NitpickFinding` itself defaults to native output regardless of loaded assemblies.
ScriptAnalyzer-compatible rules must explicitly pass `-OutputAs DiagnosticRecord`.
No global `NitpickInvocationContext` variable is used.

### Module-defined output types

Public function files dot-sourced by a script module are parsed separately from classes declared in the root `.psm1`. Referencing one of those classes as a type literal in an `OutputType` attribute, such as `[OutputType([NitpickFinding])]`, can therefore fail with `Unable to find type` while the function file is being parsed.

Use the string overload instead: `[OutputType('NitpickFinding')]`. `OutputTypeAttribute` accepts string type names, and PowerShell exposes each one through command metadata as a `PSTypeName`. The metadata retains the declared name even when its `Type` property cannot be resolved at parse time.

This would be useful to enforce with a Nitpick rule, but an unresolved output type is not enough evidence by itself. It could represent a module-defined class, an optional assembly type, an extended type name, or simply a typo. A reliable rule would need additional evidence, such as locating a matching class declaration in the same module, before recommending the string form.

### Nested script blocks

> [!WARNING]
> Pass `$false` as the `searchNestedScriptBlocks` argument when using `Ast.Find()` or `Ast.FindAll()` in a ScriptAnalyzer rule. This still traverses the current script block, but it does not enter nested script-block scopes. ScriptAnalyzer may analyze those nested scopes separately, so including them in the outer search can report the same finding more than once.

### Duplicate custom rule paths

PSScriptAnalyzer combines custom rule paths from its discovered settings file with paths passed to `-CustomRulePath`. It compares the path strings rather than the modules they resolve to, so a module directory from settings and an explicit path to that module's manifest are treated as separate rule sources. The module is loaded twice and produces duplicate diagnostic records for the same AST and extent.

For example, configuring `./src/modules/Nitpick` in `PSScriptAnalyzerSettings.psd1` while also passing `./src/modules/Nitpick/Nitpick.psd1` to `Invoke-ScriptAnalyzer` duplicates Nitpick findings. Use only one source, or pass `-Settings @{}` when an isolated invocation supplies its own custom rule path.

Nitpick should not emulate this behavior. When Nitpick accepts rules from multiple configuration or command-line sources, it should deduplicate them by resolved module identity, not by the original path strings.
