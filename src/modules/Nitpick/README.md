## Native finding identity

Coordinated native findings and corrections carry a qualified `RuleId`, such as
`Nitpick/UseIsNotOperator` or `Local/MyRule`. The executing rule descriptor owns that
identity: it replaces producer-supplied attribution during both original execution and
candidate reanalysis. Ownership follows the declaring package or registration, not
necessarily the module implementing the callable.

Text output, default finding tables, string conversion, and correction diagnostics use
qualified IDs. `RuleName` remains the coordinator-assigned local name; findings'
`RuleSuppressionID` carries that same local value for diagnostic conversion. Corrections
have no suppression field. These are transitional fields: the long-term direction is a
single `RuleId`, but this phase does not change helper signatures or suppression semantics.
Suppression remains local-name based, so equally named rules in different namespaces share
that behavior.

Parser findings use `Nitpick/PowerShellParseError`; that attribution does not create a
selectable rule or registry entry. Direct producer/helper invocation bypasses coordinated
attribution: when `RuleId` is absent, display uses the supplied `RuleName` without inventing
a namespace. No standalone `RuleId` input parameter is introduced yet.

Identity is retained across the correction proposal, application, and report without
rewriting proposal facts or changing target-wide `ChangeSetId` grouping.

## Autocorrection

Preview safe corrections and view the diff without modifying files:

```powershell
Start-Nitpicking -Path .\Example.ps1 -Fix -Preview
```

Apply the same validated transaction, or preview using standard PowerShell confirmation semantics:

```powershell
Start-Nitpicking -Path .\Example.ps1 -Fix -Confirm
Start-Nitpicking -Path .\Example.ps1 -Fix -WhatIf
```

`-Fix` now writes file-backed `-Path` targets unless `-Preview`, `-WhatIf`, or a declined
confirmation prevents it. `-Script` inputs always return in-memory output. Use `-Output Object`
for a correction envelope with `Proposal`, `Application`, and `Report` groups.
`Proposal` retains candidate text, reanalysis, skipped corrections, and conflicts regardless
of application outcome. Only `Application.CommittedCorrections` describes committed edits;
`Application.Status` records whether writing succeeded, failed, or was not requested.
Severity counts and `-ErrorOn` use `Report.EffectiveFindings`: candidate analysis for previews
and successful writes when available, original analysis for failed or declined writes.
`Report.EffectiveText` contains the selected output text. `Report.AnalysisSource`
identifies the source analyzed by `EffectiveFindings`, not necessarily `EffectiveText`:
without reanalysis, valid candidate text can accompany original findings.

Proposal diagnostics are stable by ownership, not enforced immutability.
`Proposal.Document` is the mutable queued transaction; consumers must not change its
edits between resolution and application. The result constructor rejects contradictory
lifecycle states instead of repairing them. See the
[ownership boundaries](CONTEXT.md#correction-lifecycle-ownership) for maintainer responsibilities.

The result contract intentionally breaks the earlier flat schema: use
`Proposal.AcceptedCorrections` instead of `Corrections.Accepted`,
`Application.CommittedCorrections` instead of `Corrections.Fixed`, and
`Report.EffectiveFindings` instead of `Findings.Final` or `Findings.Remaining`.
`Report.FindingsWithCommittedCorrections` attributes committed edits to original findings;
it does not claim complete resolution. The summary property is now
`FindingsWithCommittedCorrectionsCount`, replacing `FixedFindingCount`.
Failed writes do not turn valid accepted proposals into skipped corrections.

Files retain encoding, BOM, and existing newline characters through AstEditor's transactional
save. BOM-less input must be valid UTF-8; BOM-marked UTF-8, UTF-16, and UTF-32 are supported.
Byte fingerprints reject changed sources before replacement. Transactions are per target,
so a failed target does not roll back successful changes to another target. Use
`-ErrorAction Stop` to stop on a reported error.

`UseIsNotOperator` offers a native coordinated fix for `-not (<expression> -is <type>)`:
it removes only `-not` and replaces the actual operator with `-isnot`, retaining parentheses
and trivia. Redirected/background type-test pipelines remain diagnostic-only. ScriptAnalyzer
also receives diagnostics only for this rule. Finding conversion omits corrections with a
`ChangeSetId`, since ScriptAnalyzer cannot enforce atomic groups; ungrouped simple suggestions
remain available.

Phase 6 is complete: token-aware coordinated fixes use the existing single-pass
preview, validation, reanalysis, and per-target commit pipeline. No separate provider
framework is required. `ChangeSetId` is target-wide; independent producers must namespace
their IDs to avoid accidental coupling. Optional multi-pass correction remains proposed.
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

**TODO:**
  - Re-add `-FilePath` params to rules and verify ScriptAnalyzer still accepts them.
  - Add a Nitpick (editor only?) that converts fully qualified types to shorthand and adds `using namespace` for it.
  - Explore VSCode integration via `$PSEditor` (see [EditorTextManipulation.md](./src/modules/AstEditor/Docs/EditorTextManipulation.md)) for violation review/fixes. Nitpick could drive the editor from the terminal by opening the file at the occurence of the offending code and apply the fix before the user, and changes could be reverted before moving on. Sort of like a code review. Application of manual fixes would be nice but not sure how that would work. This could serve as a nice alternative to yet another editor extension. Probably won't be as straight forward as I imagine though.

### PowerShell engine quirks worth their own rules

A few language/engine quirks surfaced during the [Rule Packages](Docs/RulePackages.md) Phase 4
work that are easy to reintroduce elsewhere in this repository, and are not currently caught by
anything:

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

**TODO:**
  - Add Nitpick rules for the zero-element member-access and `ForEach-Object <MemberName>` /
    `-WhatIf` pitfalls above.
  - Use the `Select-Object -First`/`-Last` + `StopUpstreamCommandsException` defect as a concrete
    test ground for PowerShell edition/version compatibility support in Nitpick: a rule (or rule
    category) that flags constructs known to behave differently, or outright break, across
    supported PowerShell versions/editions.

## Why Not Use PSScriptAnalyzer?

"Stop reinventing the wheel", "contribute to ScriptAnalyzer instead," I hear you cry. Listen, ScriptAnalyzer is clearly king when it comes to Powershell linting, and it's unlikely that I can fully replicate all the functionality it offers, however, PSScriptAnalyzer doesn't possess the ergonomics I look for in a CLI tool. Contributing to the ScriptAnalyzer project is out of the question as I'm neither a C# dev nor would I be able to convince the maintainers to make sweeping changes just to satisfy my vision and I'm not going to put in the effort to make those changes just to be told no at merge time. ScriptAnalyzer has been around long enough that compatibility is going to be one of their core concerns and that is going to complicate any changes that might be accepted.

Moving on to more targeted points, the inability to limit a test to certain file types/names is problematic since rule suppression doesn't behave well in Pester where tests may run against purposefully incorrect code. More over, tests shouldn't be limited to files so much as scoped to them. There isn't a compelling reason why the ScriptAnalyzer should be limited to Powershell at this stage in its life. If ScriptAnalyzer runs against a Powershell file and is given a test which exposes a ScriptBlockAst parameter then the calling contract is obviously "get the Powershell AST and pass it to the test" but if given a SQL file why not just run the test and retrieve a DiagnosticRecord? Just because Powershell can't readily obtain an AST of say, SQL, doesn't mean it can't detect SQL issues by other means. The ScriptDom class from the SqlServer module can create SQL ASTs and supports vistors for analysis. Sure, there may be a better tool for the job, but it won't be PowerShell based.

Another low hanging fruit problem is the inability to have ScriptAnalyzer throw an error for a given severity. This means that using it for CI tasks or from task runners (Psake, InvokeBuild, PleaseWork) requires manually parsing the results and throwing an error yourself. Clearly this is a bad developer experience as it's manual, unintuitive, and makes the code noisy. This friction should be easy to eliminate but because ScriptAnalyzer was designed as a C# project, the people most likely to use it are forced to become C# devs to contribute back and with C#, you must compile the entire project to test that change which is another source of friction.

## Comparison

Below is a quick overview of the key differences between PSScriptAnalyzer and Nitpick.

| Criterion | PSScriptAnalyzer | Nitpick | Explanation |
| :---      | :------: | :--------: | :--- |
| **Core Language** | C# | PowerShell |  |
| **Built-In Ruleset** | 75 Rules | 2 Rules |  |
| **VSCode Integration** | Yes | No |  |
| **VSCode Debuggable** | No | Yes | ScriptAnalyzer isn't available from the VSCode Powershell Extension |
| **Configuration File** | Yes | No | |
| **Rule Categories** | No | Yes |  |
| **Rule Scoping** | No | Yes |  |
| **Nested Module Support** | No | Yes |  |
| **Errors On Failures** | No | Yes | ScriptAnalyzer doesn't throw for failures so Powershell task runners have to call it from a subprocess with `-EnableExit` or sort through the objects and throw itself. |
| **Text Mode** | No | Yes | Text mode returns text instead of objects, formatted like regular linter output. |

## Notes

- ScriptAnalyzer searches for functions named `Measure-*` and `Test-*` so we should be safe to export any helper functions from this module that do not use those verbs.
- ScriptAnalyzer's `PSUseOutputTypeCorrectly` doesn't take into account strings so `[OutputType('CustomClass')]` fails even though that's the only way it can be expressed due to parse time constraints.
