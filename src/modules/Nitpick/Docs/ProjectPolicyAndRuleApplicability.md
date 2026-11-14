# Project Policy, Invocation Context, and Rule Applicability

## Status

Implementation plan with agreed scope and behavioral contracts. Phases 1 through 4
implement validated policy, isolated context, descriptor outcomes, policy
propagation through initial and candidate analysis, and a detection-only ternary
syntax rule. Concrete implementation choices below translate those agreements
into APIs, change locations, and validation gates. Proposed internal names can
change without reopening the behavioral contracts.

[ADR 0005](adr/0005-coordinate-applicability-with-isolated-context.md) records
the accepted invocation/context ownership decision. This proposal retains its
supporting contracts, alternatives, implementation details, and deferred work.

## Agreed Scope

The first implementation will introduce general project-policy/context and
rule-applicability support, with a focused PowerShell syntax-compatibility rule
as proof of the model. Compatibility is not a separate invocation framework.

The initial compatibility proof does not claim complete runtime compatibility:
command availability, .NET API support, editions, and platforms are outside its
coverage. Additional rules may address those concerns later without redesigning
the policy/context mechanism.

The initial syntax compatibility requirement is a minimum supported PowerShell
language version, not a list of required runtimes. It constrains syntax feature
introduction dates without claiming compatibility with every later runtime.

## Agreed Configuration Entry Point

The first implementation accepts an explicit configuration-file path. Its policy
applies uniformly to the invocation's targets; a configuration does not contain
file-path-specific compatibility overrides.

Use a PSD1 data file loaded through `Import-PowerShellDataFile`, selected by
`Start-Nitpicking -ConfigurationPath`. `nitpick.psd1` is the documented convention,
not a mandatory explicit filename. Resolve relative paths against the caller's
current PowerShell location and validate once before target processing.
Omitting the path supplies no project policy; an explicit missing, unreadable,
or invalid file terminates the invocation. An in-memory configuration dictionary
parameter is outside the initial scope.

Automatic configuration discovery is deferred. The intended future direction is
nearest configuration wins, without composing or inheriting settings from parent
configurations. A nested configuration would replace the parent configuration,
not merge with it. Discovery starting points and search boundaries remain open.

[Get-RepositoryRoot in Invoke-Test.ps1](../../../../tools/Invoke-Test.ps1)
already demonstrates ancestor traversal. It locates a repository root using an
`isRoot` test configuration or `.git`, rather than selecting the nearest arbitrary
configuration. Reuse the traversal pattern where appropriate, not its resolution
or invalid-configuration fallback semantics unchanged.

## Motivation

A project may require its PowerShell code to remain compatible with Windows
PowerShell 5.1, even when Nitpick runs under PowerShell 7. A ternary operator is
valid syntax in PowerShell 7 but violates that project's requirement.

This requires more than a producer that detects ternary syntax:

1. The project must declare its compatibility requirements.
2. Nitpick must load and validate those requirements.
3. Each target must receive the appropriate effective policy through context.
4. Compatibility rules must be applicable only when relevant requirements exist.
5. Corrections and candidate reanalysis must honor the same requirements.

Compatibility is project policy, not a property inferred from the PowerShell
process running Nitpick.

## Current Behavior

- [Start-Nitpicking](../Public/Interface/Start-Nitpicking.ps1) invokes selected rules
  with isolated target context and the policy from an explicitly selected
  configuration, if provided.
- [NitpickRule.Invoke](../Nitpick.psm1) validates and recursively copies a
  plain-data context dictionary, preserving invocation defaults such as `Caller`,
  `File`, and `RuleBehavior`. It adds normalized `Policy`, submitted-target
  `TargetKind`/`TargetPath`, and actual `AnalysisHost.PowerShellVersion`. It only
  passes context to producers that declare a `Context` parameter.
  Descriptors already support `IncludePath`, `ExcludePath`, and `AppliesToPath`
  for declarative file-path eligibility.
- [Resolve-NitpickEffectiveRuleSet](../Private/Resolve-NitpickEffectiveRuleSet.ps1)
  owns invocation-level selection, exclusions, and editor-mode filtering.
- [Resolve-NitpickCorrectionProposal](../Public/Interface/Resolve-NitpickCorrectionProposal.ps1)
  forwards the original policy and target identity to candidate reanalysis.
- Whole-target suppression prevents producer execution; line and regional
  suppression filter produced findings.

The ternary syntax rule requires a PowerShell 7 or later analysis host when a
configured minimum below 7.0 makes it applicable. It is detection-only and does
not enforce policy independently when accepting corrections. The existing
terminology and correction ownership boundaries are documented in
[CONTEXT.md](../CONTEXT.md).

## Proposed Ownership

| Component | Responsibility |
| --- | --- |
| Project configuration | Declare compatibility requirements and rule settings. |
| Coordinator | Load and validate configuration, construct effective context, evaluate applicability, and expose execution outcomes. |
| Rule descriptor | Carry an optional applicability declaration alongside the producer. |
| Applicability predicate | Decide whether the rule is relevant to the effective policy without producing findings or corrections. |
| Producer | Inspect the target using context and produce findings and corrections. |

The coordinator enforces applicability, but the rule supplies its criteria.
`Start-Nitpicking` should not accumulate special cases for specific compatibility
rules, syntax features, or rule IDs.

Configuration resolution should be a focused operation, not filesystem discovery
and merging logic embedded in the producer invocation loop.

## Configuration and Effective Context

### Static project configuration

The initial configuration schema contains only syntax compatibility policy,
with strict known-key validation at every defined level:

```powershell
@{
    Compatibility = @{
        PowerShell = @{
            MinimumVersion = '5.1'
        }
    }
}
```

An empty configuration supplies no syntax requirement. Reject unknown keys
rather than ignoring possible misspellings. A general per-rule settings section
is deferred until a concrete rule requires it; the context/applicability
framework itself remains general.

Load it as data through `Import-PowerShellDataFile`, rather than
dot-sourcing an executable configuration script. Validate its schema and version
values before producer execution.

`MinimumVersion` expresses the oldest PowerShell language version the target
must support. Ternary syntax was introduced in PowerShell 7, so it violates the
example requirement of 5.1; it does not violate a requirement of 7.0 or 7.4.

Compare feature introduction versions against the declared minimum rather than
testing whether "compatibility equals 5." This contract is for syntax only.
Commands, APIs, editions, and platforms may have different support boundaries;
later rules may require a richer policy without changing this syntax contract.

Accept only a documented catalog of supported released major/minor language
versions, starting at 5.1. Configuration values are two-component strings such
as `'5.1'` and `'7.4'`, normalized to `System.Version` internally. Reject preview
labels, patch-specific values, older unsupported versions, and unknown future
versions. The catalog is independent of the current analysis host. The initial
entries are enumerated in the implementation details below.

### Effective context

Keep project requirements distinct from invocation mechanics:

- Project policy: minimum syntax version and rule-specific settings.
- Invocation data: caller, target identity, traversal behavior, and output shape.
- Analysis host: the runtime and parser actually executing Nitpick.

The existing `RuleBehavior` contract need not be renamed as part of this work.
The agreed policy path is
`Context.Policy.Compatibility.PowerShell.MinimumVersion`. Preserve existing
`Caller`, `File`, and `RuleBehavior`; add `TargetKind` and `TargetPath`, and keep
analysis-host information separate under `AnalysisHost`.

The `Policy` subtree contains normalized effective project requirements, not
invocation controls or raw arbitrary configuration. With no project policy it
is an empty dictionary; do not infer a minimum. This separation is organizational,
not a security or isolation mechanism. Configuration cannot override coordinator
metadata simply by naming the same keys.

Resolve effective policy before analyzing a target and retain that policy for
its correction lifecycle. If target-specific configuration is introduced, a
multi-file invocation must not reuse one target's policy for another.

Recursively isolated plain-data context copies are agreed. Retain a private
canonical context and supply a fresh independent copy to each applicability
predicate and each producer invocation, including candidate reanalysis. Never
reuse a predicate's copy for its producer or read local changes back into
authoritative policy. A shallow dictionary copy does not satisfy this contract.

Local mutation or ETS shadowing is permitted but cannot affect another
execution's context. Exact supported value types and cloning details are
specified through the plain-data contract rather than arbitrary-object copying.

The initial value contract is string-keyed dictionaries, arrays, null, strings,
Booleans, numeric values, and explicitly supported immutable values such as
`System.Version`. Reject unsupported objects and cyclic structures explicitly.
Copy dictionary entries and array elements, not attached ETS members. Arbitrary
PowerShell object graphs, scriptblocks, ASTs, module objects, and custom mutable
class instances are not supported context values.

The objective is cross-execution isolation, not tamper-proof objects within a
producer's own execution. PowerShell ETS can add instance members independently
of dictionary storage. A focused PowerShell 7 probe confirmed that `Add-Member`
can attach a note property to a `DynamicObject` even when `TrySetMember` throws.
The existing [WPF dynamic state implementation](../../WPF/Public/Helpers/New-WPFObservableState.ps1)
demonstrates dynamic member dispatch, not prevention of ETS additions.

A custom dynamic wrapper therefore does not establish the desired guarantee by
itself, and the illustrative wrapper does not implement the producer's required
`IDictionary` interface. Recursively isolated plain-data copies are the agreed
approach. Specify the supported context
value types and reject unsupported mutable objects rather than claiming that an
arbitrary object graph can be safely cloned. Measure overhead before optimizing.

A second PowerShell 7 probe exercised a custom `IDictionary` backed by
`ImmutableDictionary`, with mutation methods throwing. `Add-Member` still added
an instance note property and shadowed `Count`; a nested hashtable value remained
mutable. Implementing read-only dictionary methods protects storage, not ETS
member collections or nested values. Comments about intercepting `GetType` or
forcing type data do not implement such interception.

### Absence and invalid configuration

- A valid minimum-version declaration enables syntax compatibility checking.
  No separate enable switch is required.
- Missing compatibility policy means compatibility checks are not applicable.
  It does not imply the analysis host's version is the project's requirement.
- Malformed configuration produces an explicit configuration error, not an
  apparently clean analysis or silent fallback.
- Empty, malformed, or unsupported minimum-version values are configuration
  errors, never alternative ways to disable checking. Accept documented
  major/minor releases and normalize to `System.Version` as described above.
- Configuration discovery, precedence, and inheritance must be specified before
  implicit project-file lookup is implemented.

### Target identity and fragment provenance

Expose `TargetKind` and nullable `TargetPath` in applicability context. File
targets have a target path; fragments do not, even when their snapshot originated
in a file. Explicit invocation policy applies to both kinds of target.

Preserve existing `Context.File` as legacy snapshot provenance rather than
silently redefining it as target identity. Path-dependent predicates use
`TargetPath` and explicitly handle its absence. Fragment provenance must not
implicitly select project policy or turn the fragment into a file target.

## Rule Applicability

Keep three independent concepts:

| Concept | Meaning |
| --- | --- |
| Selected | Included by invocation-level rule selection. |
| Applicable | Relevant to this target's effective policy. |
| Suppressed | Disabled by a recognized suppression directive. |

An inapplicable rule is still a known rule. Applicability should not invalidate an
explicit include selector or change a rule's identity.

### Recommended mechanism

An optional rule-declared applicability predicate, enforced by the coordinator,
is agreed. It accepts invocation context so it can inspect effective policy and
target information before producer execution. The exact context contract remains
subject to the plain-data contract above. Context exposes target identity,
effective policy, and invocation metadata,
not ASTs, tokens, or source text. Content inspection belongs in the producer.
Rules without a predicate retain their existing eligibility behavior.

Existing declarative path eligibility remains independent. A context predicate
can further restrict execution but cannot override an `IncludePath` or
`ExcludePath` rejection. The conjunction of applicable gates determines whether
the producer executes.

Host support is a separate prerequisite: a needed check that cannot execute on
the analysis host must not be classified as inapplicable.

Predicates are initially ScriptBlock-valued rule metadata. Command-backed rules
declare them through `-Details`; local rules supply them through creation and
registration parameters. The predicate receives one `IDictionary` context
argument. Preserve the declaration through discovery, reconstruction, and
registration overrides. Named predicate commands and executable predicates in
project configuration are outside the initial scope. Proposed field names and
dispatch APIs are specified in the concrete implementation details below.

The agreed target execution order is invocation-level selection, declarative
path eligibility, whole-target suppression, context applicability, host
prerequisites, and producer execution. Line and regional suppression filter
produced findings afterward.

Whole-target suppression bypasses the predicate and host checks. Line/regional
suppression does not bypass them, because those actions require produced
findings. Parser findings remain unsuppressible.

The ternary proof's predicate requires a configured minimum version below 7.0.
It does not inspect the target's syntax to decide whether to run.

The predicate must return exactly one Boolean: true means applicable and false
means inapplicable. Missing output, multiple output objects, non-Boolean values,
and predicate exceptions are explicit execution errors, not "not applicable."
Do not use PowerShell truthiness to interpret results. An author-provided reason
or structured applicability result is outside the initial contract.

This mechanism lets Nitpick distinguish "not applicable" from "executed with no
findings" and eventually explain why a selected rule did not run.

If all selected rules are inapplicable, the invocation is a successful no-op,
not a selection error. Preserve selected-rule totals and identify inapplicable
outcomes through verbose diagnostics rather than ordinary finding output.
Parser findings still report normally.

### Alternative: producer early returns

An early return inside the producer is a smaller initial change and can express
the same compatibility condition. Its limitation is observability: an empty
result does not reveal whether the rule was irrelevant or found no violations.
It also encourages repeated policy guards across producers.

Do not require both an applicability predicate and a duplicate producer guard
for coordinated execution. Direct `NitpickRule.Invoke` calls also enforce
context applicability and host prerequisites, without loading configuration.
Missing compatibility policy makes the compatibility rule inapplicable;
required analysis on an unsupported host errors.

`Start-Nitpicking` retains ownership of configuration loading, path eligibility,
suppression, and execution reporting. Reuse shared applicability/host evaluation
logic without invoking a predicate twice for one dispatch. The outcome-producing
dispatch proposed below keeps both paths consistent.

Direct raw producer invocation bypasses coordinator-owned applicability and
host-prerequisite enforcement, just as it bypasses coordinated attribution.

## Corrections and Candidate Reanalysis

Compatibility policy must influence corrections offered by ordinary rules too.
For example, a simplification rule must not introduce a ternary operator into
code required to support 5.1.

Pass the same effective policy through initial analysis, correction handling,
and candidate reanalysis. Reconstruct target-dependent invocation data for a
candidate while preserving project requirements. Never replace policy with an
empty dictionary during reanalysis.

`Resolve-NitpickCorrectionProposal` accepts optional context for direct callers,
using the same normalization/isolation helpers. It does not discover or load
configuration. `Start-Nitpicking` supplies resolved context automatically; direct
callers supply the policy used for their initial analysis. Omission retains
no-policy behavior.

Evaluate applicability consistently during candidate analysis using equivalent
policy and target identity. Predicates do not inspect content, so source edits
alone must not change applicability. Candidate analysis still honors changes to
suppression directives, which are a separate concern.

Preserve whole-fix atomicity, suppression behavior, and the existing correction
ownership boundaries. Initially, honoring syntax policy is a producer obligation:
propagate policy to correction-producing rules and report violations through
ordinary selected, applicable, unsuppressed compatibility rules during
reanalysis. A compatibility finding does not independently reject the candidate.

Independent syntax-policy validation of correction acceptance is a follow-up,
not part of the basic implementation. It would need to distinguish pre-existing
unsupported syntax from syntax introduced by corrections and explicitly define
its relationship to rule selection and suppression. Until implemented, Nitpick
must not claim a universal guarantee that corrections cannot introduce
incompatible syntax.

## Execution Failures

Configuration errors, invalid predicate results, predicate exceptions, and
required checks on unsupported analysis hosts terminate the invocation. They
are execution errors, not ordinary findings or inapplicable outcomes.

Do not apply the affected target's corrections after such a failure or present
its analysis as complete and clean. There is no invocation-wide rollback:
corrections already persisted for earlier targets remain applied. Configuration
validation should occur before target processing where possible.

## Analysis-Host Limitations

Host prerequisites are initially optional minimum analysis-host PowerShell
version metadata, declared through the rule's metadata/creation surfaces.
Rules without a declaration preserve existing behavior. The ternary proof
declares 7.0. Validate declaration shape during discovery, but check whether the
host meets it only after applicability. Discovery and `-Details` must remain
executable on 5.1 without unconditional references to newer syntax or unavailable
types.

The general policy/context and applicability framework retains PowerShell 5.1
support. The first newer-syntax proof rule requires PowerShell 7 for analysis.
When that check is required on an older host, report an explicit
unsupported-analysis-host error, not an inapplicable outcome or a successful
compatibility result. Raising Nitpick's global minimum host version is out of
scope.

PowerShell 5.1 and PowerShell 7 do not necessarily produce equivalent usable ASTs
for newer syntax. A ternary compatibility rule cannot assume that a 5.1 parser
will expose the same syntax nodes as a 7 parser.

A reliable older-host parser-error/token-based detection path is deferred.
Do not promise equivalent detection until it is tested on the supported hosts.

Distinguish parser findings from compatibility findings, and define behavior
when parsing fails. A runtime compatibility target does not automatically imply
that Nitpick itself can analyze every input while running on that target runtime.

## Code Integration Map

The following paths were traced before writing the phases. The table records the
baseline and planned changes, rather than describing current behavior.

| Surface | Current behavior | Planned change |
| --- | --- | --- |
| [NitpickRule](../Nitpick.psm1) | Reads `-Details`, applies overrides, funnels invocation overloads through a parameter dictionary, fills context defaults, and stamps native identity. | Add metadata and one shared outcome-producing dispatch path; construct isolated context before evaluating the predicate. |
| [New-Nitpick](../Public/Interface/New-Nitpick.ps1) | Copies explicitly bound metadata into constructor overrides. | Add applicability and host-version parameters to the explicit override list. |
| [Register-Nitpick](../Public/Interface/Register-Nitpick.ps1) | Either retains a descriptor or reconstructs it when metadata is overridden. | Preserve new fields on reconstruction, including an override of unrelated metadata such as category. |
| [Get-NitpickPackage](../Private/Get-NitpickPackage.ps1) | Obtains declared/exported commands and constructs descriptors through `New-Nitpick`. | Let descriptor construction carry new metadata; do not add target policy to package manifests. |
| [Find-Nitpick](../Public/Interface/Find-Nitpick.ps1) | Returns package descriptors filtered by rule ID. | Discover rules regardless of invocation policy or current host capability. |
| [Resolve-NitpickEffectiveRuleSet](../Private/Resolve-NitpickEffectiveRuleSet.ps1) | Validates include selectors and merges discovered/registered rules; registered metadata wins for the same callable. | Preserve that precedence; do not filter context-inapplicable rules here. |
| [Start-Nitpicking](../Public/Interface/Start-Nitpicking.ps1) | Resolves rules in `begin`, gathers targets in `process`, analyzes them in `end`, and passes empty context to rules. | Read configuration once in `begin`; construct target context in `end`; dispatch with outcomes and propagate canonical context to correction handling. |
| [Resolve-NitpickTargetCorrection](../Private/Resolve-NitpickTargetCorrection.ps1) | Builds resolver arguments, obtains the proposal, then applies/saves corrections. | Forward optional context without loading configuration; let execution errors escape before saving. |
| [Resolve-NitpickCorrectionProposal](../Public/Interface/Resolve-NitpickCorrectionProposal.ps1) | Rebuilds the candidate document and suppression, then invokes supplied rules with empty context. | Accept optional context; preserve original target identity/policy across candidate construction and use the shared dispatch path. |
| [New-AstDocument](../../AstEditor/Public/New-AstDocument.ps1) | File-path inputs are file-backed; AST/string inputs are in-memory even when their extents have file provenance. | Reuse that distinction; no AstEditor runtime changes are planned. |
| [Nitpick manifest](../Nitpick.psd1) | Separately lists exported functions and built-in `PrivateData.Linting.Rules`. | Add the proof rule to both lists; keep helper functions private and the global minimum at 5.1. |

Important existing contracts:

- The first test in [NitpickRule.Tests.ps1](../Tests/Private/NitpickRule.Tests.ps1)
  previously asserted reference equality between the supplied and producer-visible
  context. Phase 1 intentionally replaced that contract with value preservation,
  distinct identity, and mutation isolation; the dispatched document itself is
  still unchanged.
- `Start-Nitpicking` adds path-eligible descriptors to its correction reanalysis
  list before checking whole-target suppression. Preserve that behavior. The
  [suppression tests](../Tests/Public/Interface/Start-Nitpicking.Suppression.Tests.ps1)
  require a candidate edit that removes a directive to re-enable a rule.
  Do not narrow the candidate set to producers that executed initially.
- Candidate documents are rebuilt from ASTs and are therefore in-memory.
  Re-deriving identity from the candidate's file-backed flag would incorrectly
  turn an original file target into a fragment. Candidate analysis is a
  continuation of the original submitted target, not a new target submission:
  the coordinator must carry the canonical identity established from the
  original target through an internal-only channel, separate from the public
  context dictionary. Rebuild each candidate invocation context from that
  canonical identity rather than recovering identity from a predicate- or
  producer-visible context copy. The rendered candidate remains in-memory and
  is never made writable by retaining the original file identity. Direct
  callers continue to derive identity from the document they submit; public
  context or resolver parameters must not let them override `TargetKind` or
  `TargetPath`. The internal dispatch payload uses a unique in-process token
  checked by `NitpickRule` and is removed before invoking rule code. Treat it as
  an accidental-misuse boundary for this internal channel, not as protection
  against arbitrary code already running in the PowerShell process.

## Concrete Implementation Details

These are implementation choices for the agreed behavior, not additional
configuration features.

### Configuration validation and supported versions

Introduce private `Read-NitpickConfiguration` to read one explicitly selected
filesystem file and return normalized policy. Use literal-path resolution and
the repository's existing `Import-PowerShellDataFile -ErrorAction Stop` pattern.
Reject non-filesystem paths, directories, missing/unreadable files, and invalid
data explicitly. Do not execute configuration or borrow the package loader's
permissive absent-metadata defaults.

Use case-insensitive known-key validation. Every present container
(`Compatibility` and `PowerShell`) must be a string-keyed dictionary, not null,
a scalar, or an array. Empty dictionaries and an omitted `MinimumVersion` mean
no requirement; a present null/empty/invalid minimum is an error. Unknown keys
error at every level, including when no minimum is present. Normalize equivalent
empty configurations to an empty `Policy` dictionary.

Initially accept these exact major/minor strings:

```text
5.1
6.0  6.1  6.2
7.0  7.1  7.2  7.3  7.4  7.5  7.6
```

These are language-version identifiers, not a promise of vendor servicing or
complete feature coverage. PowerShell 7.6 is a released version documented in
[Microsoft's release notes](https://learn.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-76?view=powershell-7.6).
Test every accepted entry and reject `5`, `5.0`, `7`, `7.4.0`, preview suffixes,
whitespace-padded values, numeric literals, and unlisted versions such as `99.0`.
Normalize to a clean two-component `System.Version`. Maintain one catalog shared
by file validation and direct-context policy normalization, not host detection.

### Context construction and copy helpers

Introduce private `Copy-NitpickPlainData` and `New-NitpickInvocationContext`.
Keep validation/copying in these helpers rather than repeating it in producers,
descriptor overloads, and correction coordinators.

- Support null, strings, Boolean, the CLR numeric types `SByte`, `Byte`, `Int16`,
  `UInt16`, `Int32`, `UInt32`, `Int64`, `UInt64`, `Single`, `Double`, and `Decimal`,
  plus `System.Version`.
- Support string-keyed `IDictionary` values and one-dimensional arrays, including
  typed arrays. Normalize them to case-insensitive hashtables and `object[]`.
  Reject ambiguous case-duplicate keys, non-string keys, other collection types,
  multidimensional arrays, and unsupported scalars such as custom classes.
- Track the active recursion path by reference identity to reject cycles.
  Repeated non-cyclic references are allowed but produce independent copies,
  not shared mutable subgraphs.
- Read dictionary entries and array elements, not the object's ETS property
  enumeration. Materialize clean scalar values, including reconstructing
  `System.Version`, without carrying attached instance members. Test ETS
  additions on scalar values as well as dictionaries; immutable value equality
  is not permission to leak an instance wrapper.
- Preserve null entries and empty/singleton/nested array shapes without
  PowerShell pipeline enumeration or incidental success-stream output.
- Do not use serialization round-trips that change types or silently truncate
  graph depth. Unsupported values error with their context key/index path.

The constructor fills existing defaults without mutating caller input. Preserve
explicit legacy `Caller`, `File`, and `RuleBehavior` values and existing
partial-`RuleBehavior` behavior; do not change output/traversal defaults in
unrelated producers. Missing new metadata is coordinator-generated:

| Key | Value |
| --- | --- |
| `Policy` | Empty dictionary or normalized syntax requirement. |
| `TargetKind` | `File` or `Fragment`. |
| `TargetPath` | Absolute file path for file targets; null for fragments. |
| `AnalysisHost.PowerShellVersion` | Actual current host version, not caller policy. |

For direct AST/document invocation, default identity comes from the actual
submitted document: only file-backed documents identify file targets. A
provenance path alone does not. In correction reanalysis, carry the original
coordinator-owned identity explicitly instead of recomputing it from the
rendered in-memory document. Validate supplied reserved-key shapes; do not let
direct callers spoof the host version or turn an AST provenance path into a
writable file. Normalized direct policy may supply the minimum as either a
supported configuration string or a two-component `System.Version`.

Retain unknown top-level direct-context entries only when they satisfy the
plain-data contract, preserving the existing dictionary extension surface.
The project-file schema remains strict and cannot populate those entries.

### Descriptor metadata and single-evaluation dispatch

Use these proposed field and creation/registration parameter names:

| Name | Type and contract |
| --- | --- |
| `Applicability` | Optional ScriptBlock accepting one `IDictionary` context argument and returning exactly one Boolean. |
| `MinimumAnalysisHostVersion` | Optional `System.Version` prerequisite, independent of the project syntax minimum. |

Validate metadata types at descriptor construction before implicit property
conversion can disguise an invalid value. Validate a positive major/minor host
minimum; it is a host prerequisite, not a member of the syntax-policy catalog.
Validate declaration shape during discovery, but evaluate applicability and
enforce host capability only during dispatch.

Preserve both fields through `-Details`, explicit creation/registration,
registered-over-discovered precedence, and descriptor reconstruction.
Distinguish an omitted override from an explicitly null override that clears an
optional declaration. A category-only override must not discard a predicate
that was supplied when registering a scriptblock.

Add a small module-scoped `NitpickRuleInvocationResult` class before
`NitpickRule`, containing `Status` (`Executed` or `Inapplicable`) and `Results`
(`object[]`). This is an execution outcome, not a predicate result or a finding.
Introduce `InvokeWithResult` on the descriptor, with dictionary and
document/context entry points. Both delegate to one core dispatch implementation:

1. Validate/normalize the target and construct a private canonical context.
2. Invoke the predicate once with an isolated copy, capturing success output.
   Require exactly one actual Boolean. Promote predicate errors to terminating
   execution errors; do not convert them to a false result.
3. If false, return `Inapplicable` with an empty result array.
4. If true or absent, check the actual host against the optional prerequisite.
   An unmet prerequisite throws with rule ID, required version, and actual host.
5. Invoke the producer with a separate context copy if it accepts `Context`;
   otherwise omit that argument as today.
6. Stamp native findings/corrections with descriptor identity exactly as today.
   Return `Executed`, including when the producer emits zero findings.

All existing `Invoke` overloads continue to return only `object[]`, unwrapping
this outcome. Preserve declared dispatch parameter names, the legacy
`ScriptBlockAst` dictionary fallback, AstDocument dispatch, and non-native
producer output. Coordinators call `InvokeWithResult` instead of pre-running
the predicate. There is no public "already applicable" bypass flag or cached
approval object that can become stale.

This preserves existing raw producer signatures; the generic callable-signature
validator does not need new producer parameters. Predicate declarations are
trusted rule code, not config values. Preserve their original module/session
binding; test a `-Details` predicate that calls a module-private helper.

### Lifecycle propagation and execution errors

Add optional `[IDictionary] Context` to the target correction coordinator and
public correction resolver. The resolver normalizes it before correction
selection, including when no candidate reanalysis will occur. Neither loads
configuration. Direct callers must supply the policy used in initial analysis;
Nitpick cannot recover omitted policy from findings.

Keep the path-eligible descriptor set available for candidate reanalysis,
including initially suppressed descriptors. Evaluate the new predicate and host
prerequisite only after candidate whole-target suppression. If a candidate edit
removes suppression and exposes an unsupported-host rule, terminate before save.
Keep line/regional suppression after producer execution.

Emit verbose outcome messages containing the qualified rule ID and whether the
phase is original or candidate analysis. Do not add execution records to finding
output or change summary types/counters. All-inapplicable targets remain
successful no-ops apart from parser/directive findings.

Use terminating error records with stable, testable IDs distinguishing invalid
configuration, invalid context, invalid applicability output, predicate failure,
and unsupported analysis host. Include configuration/key paths or rule identity
as appropriate; preserve the underlying exception. A helper's non-terminating
`Write-Error` followed by an empty/success result is not sufficient. In `begin`,
use a terminating error rather than `return`, since `process`/`end` still run
after a plain return. Leave existing unrelated target read/write-error policy
unchanged.

Proposed error IDs are `NitpickInvalidConfiguration`, `NitpickInvalidContext`,
`NitpickInvalidApplicabilityResult`, `NitpickApplicabilityFailed`, and
`NitpickUnsupportedAnalysisHost`. Contract tests should assert these categories
without depending on localized framework exception text.

## Implementation Phases and Test Gates

Perform targeted implementation and tests phase by phase. Each phase depends on
the preceding completed phase; publish directly related help alongside each
runtime API rather than waiting until the end. Test paths below are relative to
the module.

### Phase 1: Validated policy and isolated context

Implemented. The shared private `ConvertTo-NitpickPolicy` owns schema validation
and the release catalog for both file loading and direct-context normalization.
The reader is not exported and `Start-Nitpicking -ConfigurationPath` is not
available until the coordinator phase. Each descriptor invocation receives a
fresh context; file identity is retained even when a file-backed document is
dispatched to an AST producer.

Changes:

- Add the configuration reader, copy helper, and context constructor under
  `Private`, reusing the module's recursive private-file loading.
- Refactor descriptor context construction through the new helpers while
  retaining current dispatch and identity behavior.
- Intentionally replace the context-reference-equality test with the new
  isolation contract. Do not retain both contradictory expectations.

Tests:

- New `Tests\Private\Read-NitpickConfiguration.Tests.ps1`: all accepted versions,
  invalid/missing paths, literal filenames, null/scalar containers, unknown keys,
  empty dictionaries, omitted versus invalid minimum, and normalized output.
- New `Tests\Private\NitpickInvocationContext.Tests.ps1`: every supported type,
  cycles versus repeated references, nested arrays/nulls, case-duplicate keys,
  unsupported objects, ETS shadowing, and caller-input non-mutation.
- Extend [NitpickRule.Tests.ps1](../Tests/Private/NitpickRule.Tests.ps1) for
  isolated nested values and unchanged traversal/output/dispatch behavior.

Gate: these targeted paths pass on 5.1 and 7 before introducing applicability.

### Phase 2: Rule metadata and descriptor outcomes

Implemented. Descriptors preserve optional `Applicability` and
`MinimumAnalysisHostVersion` declarations from Details and explicit overrides.
All `Invoke` overloads unwrap the shared `InvokeWithResult` dispatch; predicates
and producers receive separate context copies. Discovery and rule selection do
not run predicates or enforce host prerequisites. Explicit metadata overrides on
an already registered same-callable descriptor update its registration, while
registration without overrides remains reference-preserving and idempotent.
Public coordinator outcome reporting remains Phase 3 work.

Changes:

- Add metadata fields/parameters, outcome class, and shared `InvokeWithResult`
  dispatch; route every `Invoke` overload through it.
- Wire constructor override lists and registration reconstruction. Keep
  applicability out of discovery and invocation-level selection filtering.

Tests:

- Extend [New-Nitpick](../Tests/Public/Interface/New-Nitpick.Tests.ps1),
  [Register-Nitpick](../Tests/Public/Interface/Register-Nitpick.Tests.ps1), and
  [Find-Nitpick](../Tests/Public/Interface/Find-Nitpick.Tests.ps1) tests for field
  propagation, null clears, malformed metadata, unrelated overrides, and
  module-private predicate binding.
- Extend [NitpickRule.Tests.ps1](../Tests/Private/NitpickRule.Tests.ps1) for true,
  false, absent, missing/multiple/non-Boolean predicate output, predicate errors,
  host checks, direct invocation overloads, and producers without `Context`.
- Counter probes must show one predicate call per dispatch and no producer call
  for false or failed prerequisites. Predicate mutation must not affect its
  producer, another invocation, caller input, or metadata defaults.
- Rerun [identity contracts](../Tests/Identity.Contracts.Tests.ps1) and
  [package contracts](../Tests/RulePackages.Contracts.Tests.ps1); execution
  gating must not change rule attribution, selectors, or metadata precedence.

Gate: targeted descriptor/metadata and existing identity/package tests pass on
both hosts; an intentionally impossible host prerequisite errors only on dispatch.

### Phase 3: Configuration through initial and candidate analysis (Complete)

Changes:

- Add `Start-Nitpicking -ConfigurationPath`, load once in `begin`, construct
  canonical context per target, and consume descriptor outcomes.
- Forward optional context through target correction and proposal resolution.
  Preserve original target identity for candidate analysis through a
  coordinator-only channel separate from caller-supplied context; keep candidate
  documents in-memory and preserve the existing path-eligible reanalysis set.

Tests:

- New `Tests\Public\Interface\Start-Nitpicking.Policy.Tests.ps1`: one config read
  per invocation, relative/literal paths, file/fragment identity, verbose-only
  inapplicability, selected-rule totals, no-policy behavior, fail-fast errors
  without `-ErrorAction Stop`, and no policy leaks between invocations.
- New `Tests\Public\Interface\Resolve-NitpickCorrectionProposal.Context.Tests.ps1`:
  direct optional context, normalization errors before selection, candidate
  producer policy, file identity retained on rendered documents, direct callers
  unable to override target identity, and candidate contexts rebuilt from the
  original coordinator-owned identity.
- Extend [target correction tests](../Tests/Private/Resolve-NitpickTargetCorrection.Tests.ps1)
  to verify context forwarding and no save after candidate execution failure.
- Extend [whole-target suppression tests](../Tests/Public/Interface/Start-Nitpicking.Suppression.Tests.ps1)
  for skipped predicates/host checks and candidate re-enablement with policy.
  Retain [line](../Tests/Public/Interface/Start-Nitpicking.LineSuppression.Tests.ps1)
  and [regional](../Tests/Public/Interface/Start-Nitpicking.RegionalSuppression.Tests.ps1)
  tests proving those actions do not bypass producer execution.
- Run existing [fragment](../Tests/Public/Interface/Start-Nitpicking.Fragments.Tests.ps1)
  and [fix](../Tests/Public/Interface/Start-Nitpicking.Fix.Tests.ps1) tests across
  Off, Preview, Guided with mocked interaction, Apply, and WhatIf as applicable.
  Assert current-target bytes are unchanged after candidate predicate/host
  failure; earlier successful writes need not roll back.

Gate: targeted lifecycle paths and the complete Nitpick suite pass on Windows
PowerShell 5.1 and PowerShell 7 with fixture rules, before the production
compatibility rule is added. Parser/directive diagnostics remain visible when
selected producers are inapplicable or whole-target suppressed.

### Phase 4: Detection-only compatibility proof and user documentation (Complete)

Changes:

- Add `Public\Rules\Test-AvoidUnsupportedTernarySyntax.Rule.ps1`, with local name
  `AvoidUnsupportedTernarySyntax` and native ID
  `Nitpick/AvoidUnsupportedTernarySyntax`.
- Its predicate is true only when a configured minimum is below 7.0; its
  `MinimumAnalysisHostVersion` is 7.0. Use a PS5.1-parseable body and `-Details`
  path, avoiding static references to unavailable newer AST types during import.
- Detect ternary nodes under PS7, report Warning findings at snapshot coordinates,
  and offer no corrections. Follow existing `RuleBehavior` traversal/output
  handling and standalone producer conventions without adding a PSSA adapter.
- Add the rule to both manifest lists. Do not expand global category validation
  or add the deferred mandatory compatibility-constraint metadata here.
- Update [README.md](../README.md) with configuration usage, context/predicate
  authoring, host errors, detection coverage, and the lack of universal
  compatibility guarantees for corrections.

Tests:

- New `Tests\Public\Rules\Test-AvoidUnsupportedTernarySyntax.Tests.ps1`: on PS7,
  5.1/6.x minima flag ternary, 7.x minima do not, absent policy skips execution,
  nested traversal and fragment coordinates work, and no corrections are offered.
- Store newer syntax as strings parsed at runtime, never as PS7-only syntax in
  the test file. On 5.1, verify import/discovery, no-policy and 7.x-minimum no-ops,
  explicit host errors for an applicable 5.1 requirement, and whole-target versus
  line-suppression ordering. PS7 syntax-node assertions run only on PS7, with
  their 5.1 prerequisite-error counterparts still mandatory.
- Use a fixture correction producer to prove refusal of an incompatible fix and
  ordinary compatibility reporting after a deliberately non-compliant fix.
  Assert that findings alone do not introduce the deferred acceptance veto.

Gate: targeted proof tests pass on both hosts, followed by the complete Nitpick
suite on both hosts. Only investigate broader suites if a shared dependency or
targeted regression requires them; no AstEditor/WPF runtime change is planned.

### Validation commands for implementation

These commands are an execution recipe. Paths are relative to the Nitpick suite
configuration, as required by the repository runner. After reading the test
runner skill, combine related paths in one call per host; do not run the full
suite first. Example for phase 1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Invoke-Test.ps1 `
    -Suite Nitpick `
    -Path Tests\Private\Read-NitpickConfiguration.Tests.ps1,Tests\Private\NitpickInvocationContext.Tests.ps1,Tests\Private\NitpickRule.Tests.ps1 `
    -ExitOnError

pwsh.exe -NoProfile -File .\tools\Invoke-Test.ps1 `
    -Suite Nitpick `
    -Path Tests\Private\Read-NitpickConfiguration.Tests.ps1,Tests\Private\NitpickInvocationContext.Tests.ps1,Tests\Private\NitpickRule.Tests.ps1 `
    -ExitOnError
```

Rerun known failures first, then the phase's remaining targeted paths. Final
validation after all targeted gates pass:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Invoke-Test.ps1 -Suite Nitpick -ExitOnError
pwsh.exe -NoProfile -File .\tools\Invoke-Test.ps1 -Suite Nitpick -ExitOnError
```

Keep output compact. Coverage is a separate, explicitly requested follow-up,
not part of the default implementation loop. Before runtime changes, read the
applicable PowerShell instructions. No new test runner, serialization package,
immutable-collection dependency, or C# context wrapper is required.

## Follow-Ups

- Independently enforce syntax policy during correction acceptance.
- Add nearest-configuration discovery without parent composition.
- Add general per-rule configuration settings when supported by a concrete use
  case; the first strict schema contains only syntax compatibility policy.
- Validate rule category metadata and require compatibility rules to declare
  a compatibility constraint: the policy dimension and feature support/version
  boundary checked by the rule. For ternary syntax, this means PowerShell syntax
  introduced in 7.0, not a hard-coded project minimum of 5.1 or an analysis-host
  prerequisite. Exact metadata representation remains open for that follow-up.

## Validation Criteria

Use targeted tests through the repository test runner before broader validation.
The implementation should demonstrate:

- No configured policy preserves existing non-compatibility rule behavior.
- Missing policy skips compatibility producers; valid policy reaches producers.
- A 5.1 requirement flags ternary syntax under a supported analysis host.
- A 7-only requirement does not flag ternary syntax as incompatible.
- A minimum of 7.4 accepts ternary syntax without implying that all commands or
  APIs in the target work on that runtime.
- Malformed policy, invalid predicate output, and predicate failures surface
  explicit errors rather than a clean result.
- Rules without applicability declarations continue to execute normally.
- Explicit include selectors still resolve known but inapplicable rules.
- All-inapplicable behavior follows the agreed reporting and exit contract.
- Policy does not leak between targets, rules, or separate invocations, including
  through mutation of nested values.
- Suppression continues to work independently of applicability.
- Initial and candidate analysis receive equivalent effective project policy.
- The proof correction producer avoids introducing unsupported syntax; candidate
  reanalysis reports compatibility findings under ordinary selection/suppression
  semantics. Universal compatibility enforcement at acceptance is deferred.
- Fragment policy resolution follows the explicit contract.
- Supported analysis hosts exercise actual parser behavior, including parse
  failures, rather than substituting version-number comparisons for detection.
