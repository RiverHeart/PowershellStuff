# Typed AST Rule Dispatch

## Status

This proposal was inspired by the desire to simplify Nitpick rule creation and the possible efficiency gains it could allow for. However, the amount by which it simplifies rules is rather drastically outsized by the technical debt it would introduce, therefore, this proposal is being paused until such a time that Nitpick performance becomes bad enough to justify it, ideally with benchmarks demonstrating such.

The MVP execution path for root-`ScriptBlockAst` and `AstDocument` dispatch,
including centralized signature resolution and focused compatibility and
validation coverage, is implemented. Shared per-node AST dispatch is a later
phase. A new PSScriptAnalyzer adapter is deferred.

## Context

PSScriptAnalyzer script rules receive a root `ScriptBlockAst` and independently traverse that scope to locate relevant nodes. A narrowly focused rule therefore repeats traversal work already performed by other rules. When there are $R$ rules and $N$ AST nodes, rule-owned traversal is approximately $O(RN)$ before accounting for each rule's analysis work.

The `FindAll` nested-script-block argument also needs care. Passing `$false` still traverses the current script block, but does not enter nested script-block scopes. This avoids duplicate findings when nested scopes are analyzed separately.

PSScriptAnalyzer compatibility remains valuable, but Nitpick can provide a native rule model that centralizes traversal and dispatches only relevant nodes to each rule.

## Proposed Rule Contract

A native Nitpick rule declares exactly one dispatch parameter. In the immediate
scope it may target the root `ScriptBlockAst` or the target's `AstDocument`;
the later phase extends AST targets to any AST subtype:

```powershell
function Test-AvoidSynchronousWait {
    param (
        [System.Management.Automation.Language.ScriptBlockAst] $InputObject
    )

    # Root AST in the MVP; each matching ScriptBlockAst in the later phase.
}

function Measure-AvoidTrailingWhitespace {
    param (
        [AstDocument] $InputObject
    )

    # Analyze document text, tokens, parse errors, and source provenance together.
}
```

`InputObject` is the conventional parameter name for new native rules, but the
declared parameter name is not special: the declared type identifies the
dispatch target. A shared signature resolver validates the callable and returns
the actual parameter name and `System.Type`; the `NitpickRule` descriptor stores
both, including `DispatchParameterName`, and invocation uses that exact name.
`DispatchType` stores the actual type, not a type-name string.

Changing `DispatchType` from a string to `System.Type` is an intentional,
observable breaking change to the descriptor contract. There is no string
compatibility alias in this experimental project; descriptor consumers and
tests must compare against the type itself.

Typed `AstDocument` and AST parameters may use any name. The legacy
`ScriptBlockAst`-by-name fallback remains for untyped or `[object]` parameters;
that fallback resolves `DispatchType` to `ScriptBlockAst`. When a type is
declared, the type is authoritative and incompatible types are rejected.
For example, `[string] $ScriptBlockAst` is invalid rather than a legacy match.
Exactly one dispatch parameter is required. The only other allowed declared
parameters are optional `[System.Collections.IDictionary] $Context` and the
reserved `[switch] $Details`. `Context` is optional in the ordinary invocation
parameter set and is supplied when declared; it is the channel for invocation
data and rule configuration. A callable that exposes `Details` must declare a
separate metadata parameter set in which `Details` is mandatory and dispatch
and `Context` are absent. `New-Nitpick` invokes that set with `-Details` to
retrieve rule metadata. Callables without a metadata set may use explicit
registration metadata. Any other declared parameter is rejected so the
coordinator cannot silently omit a required input or leave unsupported
configuration inputs unbound.

For example, the normal document invocation requires its dispatch input, while
the metadata invocation requires only `Details`:

```powershell
param(
    [Parameter(Mandatory, ParameterSetName = 'Document')]
    [AstDocument] $InputObject,

    [Parameter(ParameterSetName = 'Document')]
    [System.Collections.IDictionary] $Context,

    [Parameter(Mandatory, ParameterSetName = 'Details')]
    [switch] $Details
)
```

An `AstDocument` rule receives the shared document directly, not through a
second dispatch parameter or `Context.Document`. In the later AST phase, a
node-target rule receives the matching AST node as its dispatch parameter and
may access the same `AstDocument` through optional `Context.Document`. That is
one shared reference, not a second dispatch target; the coordinator supplies it
whenever an AST-node rule declares `Context`. Optional `Context` may also carry
caller-supplied rule configuration; its configuration source and
PSScriptAnalyzer settings integration are outside this proposal. Document data
such as source text, tokens, parse errors, and provenance must not be copied
into separate context fields.

Direct `NitpickRule.Invoke($Target)` validates and invokes once on exactly the
supplied target. The later-phase direct API has two explicit input forms:
`Invoke([Ast] $Node)` for AST-targeted rules and `Invoke([AstDocument] $Document)`
for document-targeted rules. AST invocation validates assignability
against the rule's `DispatchType` and invokes once without descendant discovery.
Document-targeted rules require a real `AstDocument`; the current convenience
that converts a `ScriptBlockAst` into a newly reconstructed document is not
retained for that API. The coordinator's shared document remains authoritative
for snapshot and file metadata. In the later phase, `Start-Nitpicking`
automatically discovers AST targets for AST-typed rules; no per-run discovery
switch is needed.
Document-targeted rules run once per target and own any document-wide traversal.
Every AST-typed rule runs once for each matching node, including
`ScriptBlockAst`-typed rules. The visitor supplies the root and matching
descendants; each invocation must analyze only its supplied node. Parameter
type determines which nodes match, not whether dispatch is root-only or
per-node. No separate root/per-node mode is proposed.

## Registration

`New-Nitpick` inspects the callable when creating a rule and records metadata such as:

```text
DispatchType
DispatchParameterName
Callable
Name
Category
Source
```

One shared resolver validates and returns the dispatch parameter metadata.
Package validation and descriptor construction use the same resolver function;
they must not independently rediscover the dispatch parameter. During the MVP,
the supported targets are `ScriptBlockAst` and `AstDocument`. Legacy untyped or
`[object]` parameters named `ScriptBlockAst` remain supported. New native rules
conventionally name the parameter `InputObject`. Other AST-node targets remain
for the later phase.

`Register-Nitpick` stores the dispatch type with the rule descriptor. In the
later phase, AST-node rules can be indexed by AST type, with base-type rules
applying to assignable derived nodes:

```powershell
$Rule.DispatchType.IsAssignableFrom($AstNode.GetType())
```

Resolved rule lists can be cached by concrete node type so inheritance checks are not repeated for every node.

## Execution

`Start-Nitpicking` selects enabled rules before parsing. It creates one
`AstDocument` per target and dispatches according to each rule's declared type:

1. A document rule receives that `AstDocument` once.
2. In the MVP, a `ScriptBlockAst` rule receives `Document.Ast` once, retaining
   the current execution behavior.
3. Findings are collected from both rule kinds.

The MVP does not introduce a shared AST visitor or per-node dispatch. Those remain
part of the later typed-AST phase. The MVP's existing rule-failure behavior also
remains unchanged.

In the later phase, all `AstDocument` rules run first in ordinal `RuleId` order.
Nitpick then traverses the selected `Document.Ast` root and descendants exactly
once, depth-first in source order with the root first. It invokes each matching
AST rule in ordinal `RuleId` order; specificity does not create precedence.
Matching uses `DispatchType.IsAssignableFrom(Node.GetType())`. Any AST subtype
is valid, including `[Ast]` as a catch-all. This applies uniformly to
`ScriptBlockAst` targets: the visitor invokes a matching rule on the root and
each matching nested node. Existing AST rules must be migrated to local analysis
before this visitor is enabled; their current recursive `FindAll` behavior must
not run from every node invocation. The native dispatcher does not set
`SearchNestedScriptBlocks` to true for these per-node calls.

### Rule Error Handling

In that later phase, a failure is isolated to the current rule and Target.
Nitpick surfaces one error attributed to the rule and failing AST node, skips
that rule's remaining node invocations for the current Target, and continues
other rules. The failed-rule state resets for the next Target. For example, if
a migrated `[UnaryExpressionAst] $InputObject` version of
`Test-UseIsNotOperator` encounters an exception on one unary expression in a
file Target, Nitpick does not invoke that rule on later unary expressions in
that same file, but other rules continue; the next file Target starts fresh.
An AST node is an invocation input, not a Target, unless the user submitted
that node as the `-Script` fragment. `Start-Nitpicking -FailFast` instead stops
the run on the first rule failure. Neither behavior is part of the MVP repair.

Use a per-Target HashSet[string] of failed RuleIds. A set expresses membership directly, avoids duplicates, and has constant-time lookups. Since the rule registry uses PowerShell hashtables, OrdinalIgnoreCase is a reasonable comparer for consistent RuleId matching.

Create a new set inside each Target iteration; then there’s nothing to clear manually. Before each (rule, node) invocation, skip the rule if its ID is in the set. Catch failures only around that invocation, add the RuleId, and report the error once. Other rules continue; the next Target gets a fresh set. -FailFast would instead stop on the first failure.

That state belongs in the later per-node visitor—not in the current Start-Nitpicking rule loop, where each rule currently runs once per Target. The loop is in Start-Nitpicking.ps1.Yes, that’s the right idea, but I’d use a HashSet[string] rather than a List[string]. The coordinator only needs membership checks (“has this rule already failed for this Target?”), and a set avoids repeated linear scans.

Create a fresh set inside each Target’s processing loop, before rule dispatch:

Before invoking a rule on a node, skip it if $FailedRules.Contains($Rule.Id). On its first failure, add its RuleId, report the error, and continue with other rules. The set then goes out of scope at the end of that Target, so there’s no separate cleanup or risk of suppressing the rule on the next file or fragment. The case-insensitive comparer matches the registry’s PowerShell hashtable behavior.

This tracking is relevant to future per-node dispatch; document rules run only once per Target.

## PSScriptAnalyzer Compatibility

This milestone does not build a new adapter or change existing direct
PSScriptAnalyzer-compatible rule entry points. A new adapter remains deferred
as recorded in [ADR 0001](adr/0001-defer-scriptanalyzer-adapter.md); the package
contract also lists one as a non-goal. The native dispatch contract does not
require every rule to retain direct PSScriptAnalyzer compatibility.

If a separate future decision revisits an adapter, it must account for the
documented limitation in [ADR 0003](adr/0003-corrections-are-whole-fixes-with-atomic-edits.md):
only single-edit corrections can be exported faithfully; multi-edit atomic
corrections cannot be represented by PSScriptAnalyzer.

## Benefits

- One shared AST traversal for native AST-node rules in the later phase.
- Rule signatures describe the nodes they actually analyze.
- Document-wide rules receive the snapshot, tokens, parse errors, and provenance
  as one authoritative input.
- Rules no longer repeat `FindAll` type-filtering boilerplate.
- Centralized handling of nested scopes and duplicate prevention.
- A natural place to cache dispatch and shared analysis context.
- A consistent per-node contract for all AST-typed rules.

## Future Work

- Migrate existing AST-typed rules to local analysis before enabling per-node
  dispatch; accept that this changes native execution behavior.
- Benchmark shared-dispatch overhead against independent `FindAll` calls on representative files and rule sets.
- Define the structured error record and summary shape for isolated rule failures.
- Reconsider a PSScriptAnalyzer adapter only through a separate decision that
  explicitly addresses ADR 0001, RulePackages.md, and the ADR 0003 limitation.

Typed dispatch does not change the existing identity model. Coordinated execution
continues to use the descriptor's identity, while standalone producers and the
existing direct PSScriptAnalyzer entry points retain their current identity
behavior. This is a scope choice to avoid changing the existing glossary, not a
claim that the current implementation is technically preferable.

## Suggested Implementation Sequence

1. Implement one shared dispatch-signature resolver that returns the actual
   parameter name and `System.Type`; use it for both package validation and
   descriptor construction.
2. Existing rules that expose `Details` now declare it as mandatory in a
   separate metadata parameter set, with dispatch and `Context` absent; normal
   invocation parameters remain in the ordinary parameter set.
3. Change `DispatchType` from string to `System.Type` as the intentional
   descriptor-contract break; update descriptor consumers and tests.
4. Add focused tests for typed `AstDocument`, typed `ScriptBlockAst` under
   arbitrary parameter names, untyped and `[object]` legacy `ScriptBlockAst`
   fallback, incompatible declared types, ambiguous signatures, invocation
   using the actual declared parameter name, and the separate mandatory
   `Details` parameter set (without dispatch or `Context`). Direct document
   invocation is covered by [NitpickRule.Tests.ps1](../Tests/Private/NitpickRule.Tests.ps1).
   [Test-AvoidTrailingWhitespace.Tests.ps1](../Tests/Public/Rules/Test-AvoidTrailingWhitespace.Tests.ps1)
   exercises document-rule dispatch through `Start-Nitpicking`, correction,
   and reanalysis.
5. In the later phase, add and test `Invoke([Ast] $Node)` for AST-targeted rules,
   including assignability validation, one-call/no-discovery behavior, and
   rejection of AST input for document-targeted rules. Replace or constrain the
   current `ScriptBlockAst` overload so it cannot implicitly convert AST input
   for document-targeted rules. Require `Invoke([AstDocument] $Document)` for
   document rules.
6. Implement and test the shared visitor, migrate all existing AST-typed rules
   to local analysis, and verify nested findings are emitted once.
7. Add future error isolation and `Start-Nitpicking -FailFast` behavior, then
   benchmark shared dispatch against independent traversal.
