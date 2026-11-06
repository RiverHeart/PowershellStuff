# Typed AST Rule Dispatch

## Status

Immediate scope is restoring and validating dispatch between legacy root-
`ScriptBlockAst` rules and native `AstDocument` rules. The dispatch plumbing is
still in progress; this document does not claim the MVP is complete. Shared
per-node AST dispatch is specified as a later phase.

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

    # Legacy root-AST rule.
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
`DispatchType` stores the actual type, not a type-name string. The same resolver
must be used for package validation and descriptor construction.

Typed `AstDocument` and AST parameters may use any name. The legacy
`ScriptBlockAst`-by-name fallback remains for untyped or `[object]` parameters;
that fallback resolves `DispatchType` to `ScriptBlockAst`. When a type is
declared, the type is authoritative and incompatible types are rejected.
Exactly one dispatch parameter is required.

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
supplied target. In the later phase, `Start-Nitpicking` automatically selects
root discovery for AST-targeted rules; no per-run discovery switch is needed.
Document-targeted rules run once per target and decide in their own logic
whether to inspect nested content. AST-targeted rules are invoked on each
discovered node and should treat that node as a local scope.

The PSScriptAnalyzer adapter remains scope-oriented. Its adapter-only
scope-local setting preserves PSScriptAnalyzer's behavior when nested script
blocks are analyzed separately; it is not part of native dispatch policy.

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

Registration rejects missing or ambiguous dispatch parameters. During the MVP,
the existing root-`ScriptBlockAst` rule signature remains supported, including
legacy untyped parameters named `ScriptBlockAst`, and `AstDocument` is added as
a second supported dispatch type. New native rules conventionally name the
parameter `InputObject`. General AST-node dispatch remains a later phase.

`Register-Nitpick` stores the dispatch type with the rule descriptor. Later,
typed AST-node rules can be indexed by AST type, with base-type rules applying to
assignable derived nodes:

```powershell
$Rule.DispatchType.IsAssignableFrom($AstNode.GetType())
```

Resolved rule lists can be cached by concrete node type so inheritance checks are not repeated for every node.

When a module exports both a native producer and a PSScriptAnalyzer adapter, its
`PrivateData.Linting.Rules` declaration must list only the native producer.
Legacy auto-discovery for modules without that declaration remains unchanged.
The adapter stays available as an exported PSScriptAnalyzer entry point but is
not registered as a duplicate native rule.

## Execution

`Start-Nitpicking` selects enabled rules before parsing. In the MVP it creates
one `AstDocument` per target and dispatches according to each rule's declared
type:

1. A document rule receives that `AstDocument` once and owns its nested-content
   analysis.
2. A legacy root-`ScriptBlockAst` rule receives `Document.Ast` once. Until the
   visitor is implemented, it retains the current `SearchNestedScriptBlocks`
   compatibility context so existing native recursive behavior does not change.
3. Findings are collected from both rule kinds.

The MVP does not introduce a shared AST visitor or per-node dispatch. Those remain
part of the later typed-AST phase. The MVP's existing rule-failure behavior also
remains unchanged.

In the later phase, all `AstDocument` rules run first in ordinal `RuleId` order.
Nitpick then traverses the selected `Document.Ast` root and descendants exactly
once, depth-first in source order with the root first. It invokes each matching
AST rule in ordinal `RuleId` order; specificity does not create precedence.
Matching uses `DeclaredType.IsAssignableFrom(Node.GetType())`. Any AST subtype
is valid, including `[Ast]` as a catch-all. Native AST rules receive local
targets and should not recurse unless that is deliberately their own behavior.
When this visitor is in place, the legacy recursion context is retired from
native AST dispatch.

In that later phase, a rule failure is surfaced with its rule attribution and
does not stop unrelated rules by default. `Start-Nitpicking -FailFast` restores
fail-fast behavior. This policy and switch are not part of the MVP repair.

## PSScriptAnalyzer Compatibility

Typed native rules cannot be discovered directly as PSScriptAnalyzer script rules because PSScriptAnalyzer expects its own supported parameter signatures. Compatibility should be implemented as an adapter, not imposed on the native contract.

The adapter receives the `ScriptBlockAst` supplied by PSScriptAnalyzer, creates
an `AstDocument`, sets `Context.RuleBehavior.SearchNestedScriptBlocks` to
`$false` for that adapter invocation, delegates to the native rule, and converts
its `NitpickFinding` results to `DiagnosticRecord` objects. This preserves the
scope-local behavior when PSScriptAnalyzer analyzes nested script blocks
separately. Native Nitpick dispatch does not set this adapter compatibility
flag. The producer always returns native findings; output-format conversion
belongs to the adapter.

PSScriptAnalyzer-style rules remain adapter entry points. Native document rules
can have separate adapters; adapter commands are not registered as duplicate
native rules. Native document rules and legacy root-AST rules are identified
explicitly in registration metadata.

## Benefits

- One shared AST traversal for native AST-node rules in the later phase.
- Rule signatures describe the nodes they actually analyze.
- Document-wide rules receive the snapshot, tokens, parse errors, and provenance
  as one authoritative input.
- Rules no longer repeat `FindAll` type-filtering boilerplate.
- Centralized handling of nested scopes and duplicate prevention.
- A natural place to cache dispatch and shared analysis context.
- Continued access to the PSScriptAnalyzer ecosystem through an adapter.

## Future Work

- Decide which existing AST-node rules migrate first and their compatibility window.
- Benchmark shared-dispatch overhead against independent `FindAll` calls on representative files and rule sets.
- Define the structured error record and summary shape for isolated rule failures.

Typed dispatch does not change the existing identity model. Coordinated execution
continues to use the descriptor's identity, while standalone producers and the
PSScriptAnalyzer adapter retain their current identity behavior. This is a scope
choice to avoid changing the existing glossary, not a claim that the current
implementation is technically preferable.

## Suggested Implementation Sequence

1. Add the shared dispatch-signature resolver and test actual parameter-name
   binding, type validation, and legacy compatibility.
2. Store target metadata and restore direct `AstDocument` dispatch without
   changing legacy root-AST behavior.
3. Keep the PSScriptAnalyzer adapter separate, with adapter-owned scope-local
   behavior and `DiagnosticRecord` conversion; list only the producer in the
   module's native rule manifest.
4. Add focused integration tests for direct rule invocation and
   `Start-Nitpicking`; leave the shared visitor and new failure policy deferred.
5. In the later phase, implement and test the single-pass visitor and its agreed
   matching and ordering rules.
6. Migrate one narrow AST rule, add the future error-isolation/`-FailFast`
   behavior, and benchmark against independent traversal.
