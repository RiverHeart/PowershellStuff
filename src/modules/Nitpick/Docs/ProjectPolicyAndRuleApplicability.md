# Project Policy, Invocation Context, and Rule Applicability

## Status

Design proposal with agreed scope and behavioral contracts; not implemented.
This document is a basis for an implementation plan. Remaining implementation
details and follow-ups are distinguished from the agreements below.

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
  with an empty context dictionary.
- [NitpickRule.Invoke](../Nitpick.psm1) accepts a context dictionary and fills in
  invocation defaults such as `Caller`, `File`, and `RuleBehavior`. It only passes
  context to producers that declare a `Context` parameter.
  Descriptors already support `IncludePath`, `ExcludePath`, and `AppliesToPath`
  for declarative file-path eligibility.
- [Resolve-NitpickEffectiveRuleSet](../Private/Resolve-NitpickEffectiveRuleSet.ps1)
  owns invocation-level selection, exclusions, and editor-mode filtering.
- [Resolve-NitpickCorrectionProposal](../Public/Interface/Resolve-NitpickCorrectionProposal.ps1)
  also invokes rules with an empty context during candidate reanalysis.
- Whole-target suppression prevents producer execution; line and regional
  suppression filter produced findings.

There is not yet a project-policy loading or applicability contract. The existing
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
versions. The catalog is independent of the current analysis host. Its exact
initial entries must be enumerated and tested during implementation.

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
project configuration are outside the initial scope. Exact property/parameter
names remain open.

The agreed target execution order is invocation-level selection, declarative
path eligibility, whole-target suppression, context applicability, host
prerequisites, and producer execution. Line and regional suppression filter
produced findings afterward.

Whole-target suppression bypasses the predicate and host checks. Line/regional
suppression does not bypass them, because those actions require produced
findings. Parser findings remain unsuppressible.

A compatibility rule's predicate could require a configured PowerShell version
policy. A narrowly focused ternary rule could additionally require a minimum
version below 7. The exact predicate API and granularity remain open.

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
logic without invoking a predicate twice for one dispatch. The dispatch/result
mechanism needed to achieve this remains open.

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
declares 7.0; validate and check it after applicability, not during discovery.
Discovery and `-Details` must remain executable on 5.1 without unconditional
references to newer syntax or unavailable types.

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

## Remaining Implementation Details

These details must be resolved and covered by tests while producing the concrete
implementation plan; they do not reopen the behavioral agreements above:

- Enumerate the initial supported major/minor release catalog.
- Enumerate supported numeric and immutable scalar types; implement dictionary
  and array copying without carrying ETS members or permitting cycles.
- Name the ScriptBlock applicability and minimum-analysis-host metadata fields,
  preserving them through every creation, discovery, and registration surface.
- Define context construction/default ownership for direct descriptor/resolver
  calls while preserving legacy producer behavior.
- Choose a shared dispatch/result mechanism that evaluates the predicate once
  per dispatch, enforces prerequisites for direct descriptor invocation, and
  exposes inapplicable outcomes to verbose reporting.
- Validate nested schema container types and distinguish omission from invalid
  null/scalar values without silent defaults.

Automatic discovery boundaries/precedence, independent correction enforcement,
and richer compatibility metadata remain follow-up design work, not blockers
for this implementation.

## Suggested Implementation Sequence

### 1. Translate agreed contracts into an implementation plan

Use the agreements above to settle the remaining implementation details and
write focused contract tests. Record architectural decisions in an ADR only
where the trade-off warrants it. This document describes intended behavior, not
proof that the behavior is implemented.

### 2. Implement policy loading and context construction

Add validated data-file loading and explicit effective-policy construction.
Preserve behavior for callers without configuration and producers without a
`Context` parameter. Establish isolation before sharing policy across rules.

### 3. Wire the complete analysis lifecycle

Propagate effective policy through initial analysis, target correction handling,
and candidate reanalysis. Follow the existing component ownership boundaries
instead of adding policy resolution independently at each invocation site.

### 4. Add coordinator-enforced applicability

Carry the declaration through rule creation, discovery, registration, and
effective-rule resolution. Validate predicates and expose a distinct execution
outcome for inapplicable rules. Preserve selection and suppression semantics.

### 5. Prove the model with compatibility behavior

Implement a detection-only ternary compatibility rule under the chosen host
strategy. An automatic ternary rewrite is outside the initial scope. Use a
focused test producer to exercise refusal to offer an incompatible correction
and test policy propagation into candidate reanalysis; do not introduce an
unrelated production style rule solely to prove the infrastructure. Do not add
independent compatibility rejection to correction acceptance in this basic
implementation.

### 6. Publish the accepted contract

Update user-facing configuration examples and rule-authoring documentation.
Document standalone invocation, analysis-host limitations, and observable
outcomes. Add stable terminology to the glossary only once agreed.

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
