# Typed AST Rule Dispatch

## Status

Proposed architecture for exploration. This document does not define the current Nitpick rule contract.

## Context

PSScriptAnalyzer script rules receive a root `ScriptBlockAst` and independently traverse that scope to locate relevant nodes. A narrowly focused rule therefore repeats traversal work already performed by other rules. When there are $R$ rules and $N$ AST nodes, rule-owned traversal is approximately $O(RN)$ before accounting for each rule's analysis work.

The `FindAll` nested-script-block argument also needs care. Passing `$false` still traverses the current script block, but does not enter nested script-block scopes. This avoids duplicate findings when nested scopes are analyzed separately.

PSScriptAnalyzer compatibility remains valuable, but Nitpick can provide a native rule model that centralizes traversal and dispatches only relevant nodes to each rule.

## Proposed Rule Contract

A native Nitpick rule declares exactly one parameter whose type derives from `System.Management.Automation.Language.Ast`:

```powershell
function Test-AvoidSynchronousWait {
    param (
        [System.Management.Automation.Language.CommandAst] $CommandAst
    )

    # Analyze one matching node and emit zero or more findings.
}
```

The parameter name is not significant. Its declared .NET type identifies the rule's target AST type. This supports both concrete types such as `CommandAst` and base types such as `StatementAst`.

Optional recognized context parameters could provide data that does not belong to the target node, for example:

- `RootAst`
- `FilePath`
- tokens or parser errors
- analysis context shared across rules

The initial implementation should keep this context contract small and explicit.

## Registration

`New-Nitpick` inspects the callable when creating a rule and records metadata such as:

```text
TargetAstType
TargetParameterName
Callable
Name
Category
Source
```

Registration should reject ambiguous signatures with no AST-derived parameter or more than one AST-derived parameter. Untyped legacy `ScriptBlockAst` parameters require an explicit compatibility decision rather than inferred intent.

`Register-Nitpick` stores the rule and indexes it by target AST type. Rules targeting a base type apply to nodes of any assignable derived type:

```powershell
$Rule.TargetAstType.IsAssignableFrom($AstNode.GetType())
```

Resolved rule lists can be cached by concrete node type so inheritance checks are not repeated for every node.

## Execution

`Start-Nitpicking` selects enabled rules before parsing and traversal. The native invocation path then:

1. Parses each input into a root `ScriptBlockAst`.
2. Traverses the AST once.
3. Resolves the compatible rules for each node's concrete type.
4. Invokes each compatible rule with the node and recognized context.
5. Collects emitted findings.

The expected traversal and dispatch cost is closer to $O(N + M)$, where $M$ is the number of applicable node-rule invocations. Rule-specific analysis work remains additional.

Nested script blocks need one documented ownership model. The simplest native model is one complete traversal from the file root, visiting every node exactly once. This differs from PSScriptAnalyzer's scope-oriented invocation and should not inherit its duplicate-avoidance conventions accidentally.

## PSScriptAnalyzer Compatibility

Typed native rules cannot be discovered directly as PSScriptAnalyzer script rules because PSScriptAnalyzer expects its own supported parameter signatures. Compatibility should be implemented as an adapter, not imposed on the native contract.

The adapter receives the `ScriptBlockAst` supplied by PSScriptAnalyzer, performs Nitpick's traversal and dispatch for the applicable scope, and converts Nitpick findings to `DiagnosticRecord` objects. It must preserve the `$false` nested-scope behavior when PSScriptAnalyzer analyzes nested script blocks separately.

Existing PSScriptAnalyzer-style rules can remain supported during migration through a legacy execution path. Native typed rules and legacy root-AST rules should be identified explicitly in registration metadata rather than distinguished during every invocation.

## Benefits

- One shared AST traversal for native rules.
- Rule signatures describe the nodes they actually analyze.
- Rules no longer repeat `FindAll` type-filtering boilerplate.
- Centralized handling of nested scopes and duplicate prevention.
- A natural place to cache dispatch and shared analysis context.
- Continued access to the PSScriptAnalyzer ecosystem through an adapter.

## Risks and Open Decisions

- Define whether `ScriptBlockAst` rules receive only the file root or every nested script block in native mode.
- Decide how untyped legacy parameters are classified.
- Define ordering when several base-type and concrete-type rules match a node.
- Decide whether a rule may request tokens, parser errors, or semantic context alongside its target node.
- Ensure one rule failure can be attributed and handled without terminating unrelated rules.
- Benchmark dispatch overhead against independent `FindAll` calls on representative files and rule sets.
- Determine how module manifests advertise native rules versus PSScriptAnalyzer-compatible entry points.

## Suggested Implementation Sequence

1. Add target-type discovery and validation to rule creation without changing execution.
2. Store target metadata and build a registry index by AST type.
3. Introduce a native AST visitor and typed dispatcher behind focused tests.
4. Define and test nested-script-block ownership.
5. Add the PSScriptAnalyzer adapter and duplicate-finding integration tests.
6. Migrate one narrow rule as a benchmark and compatibility proof.
7. Retain the legacy path until existing rules have an explicit migration strategy.
