# State Scriptblock Syntax Investigation

Date: 2026-06

## Why this was explored

The WPF DSL generally prefers trailing scriptblock syntax. `State` historically used hashtable input:

- `State @{ Count = 0 }`

We explored a scriptblock form:

- `State { Count = 0 }`

The goal was readability and syntax consistency across DSL keywords.

## What we tried

### 1) Rebuild as hashtable text and execute

Approach:

- Convert scriptblock body text into `@{ ... }` by adding hashtable start/end markers.
- Execute the generated scriptblock.

Why it looked reasonable:

- Keeps hashtable semantics.
- Small implementation.

Observed issue:

- Recreating a scriptblock changed invocation context.
- Caller variable resolution became unreliable in some cases.

### 2) Variable injection workaround on generated scriptblock

Approach:

- Parse variable references from AST.
- Resolve values from outer scopes.
- Temporarily inject those variables into local scope before evaluating the generated hashtable scriptblock.

Why it looked reasonable:

- Improved several common scenarios.

Observed issues:

- Still inconsistent across module boundaries and nested scope situations.
- Behavior depended on how the scriptblock was invoked, not just script content.

### 3) Reflection-based invocation (InvokeUsingCmdlet path)

Approach:

- Use non-public scriptblock invocation APIs to mimic pipeline-style caller-context resolution.

Why it looked reasonable:

- Foreach/pipeline semantics can resolve caller context in ways normal invocation may not.

Observed issues:

- Still not deterministic for our wrapped-hashtable/module scenarios.
- Relied on internal APIs and fragile behavior.

### 4) Command-capture mini-DSL execution

Approach:

- Execute original scriptblock with temporary command handlers keyed by assignment names.
- Capture values into a hashtable.

Why it looked reasonable:

- Preserves original scriptblock context better.

Observed issues:

- Changes semantics from hashtable evaluation to assignment-command capture.
- Higher risk of edge-case drift and maintainability cost.

## Main failure themes

1. Runspace affinity and session-state binding were the core reliability problems.
2. Public APIs do not provide robust control over those internal bindings.
3. Scriptblock recreation and rebinding paths introduced context-dependent behavior.
4. Early tests emphasized literal values, so variable-context regressions were easy to miss.

## Invocation context examples

These examples reflect the observed pattern during investigation.

### Example A: Literal assignments appear healthy

```powershell
State {
	Count = 3
	IsReady = $true
}
```

Why this is misleading:

- No external variable lookup is needed.
- Context issues can exist and still pass this case.

### Example B: Caller variable can resolve incorrectly

```powershell
$seed = 123

Window 'W' {
	State {
		Count = $seed
	}
}
```

Expected:

- `Count = 123`

Observed in failing paths:

- `Count` became stale/unexpected (for example `11`) or `$null`.

### Example C: Nested-scope variable often fails first

```powershell
function Build-Window {
	$innerSeed = 456

	Window 'W' {
		State {
			Count = $innerSeed
		}
	}
}
```

Expected:

- `Count = 456`

Observed in failing paths:

- `Count` often resolved as `$null`.

### Example D: Module boundary amplifies the issue

```powershell
# Caller script scope
$seed = 123

# Helper executes inside module scope
Invoke-StateHelperFromModule { Count = $seed }
```

Expected:

- Helper resolves caller value (`123`).

Observed in failing paths:

- Resolution sometimes drifted to module/session state instead of caller state.

### Why this matters

- Literal-only tests can pass while real state expressions are wrong.
- `State` values are often expressions (`$seed`, conditional expressions, nested calculations), so context correctness is part of the functional contract.

## Testing gap that was discovered

The passing `State` tests primarily covered literal assignments. They did not strongly cover:

- Caller-scope variable use inside state declarations.
- Nested function/module boundary variable resolution.

These are exactly the scenarios where failures appeared.

## Current direction

Given reliability concerns, the safer and clearer contract is to keep `State` on explicit hashtable input.

- Preferred stable form: `State @{ ... }`

If scriptblock form is revisited in the future, treat it as a separate execution model with strict syntax limits and dedicated regression tests for caller-scope, nested scope, and module-boundary behavior.

## Suggested future guardrails

1. Add explicit tests for caller and nested scope variable capture before changing `State` input model again.
2. Document exact accepted syntax (and non-goals) if scriptblock mode is reintroduced.
3. Prefer deterministic public API behavior over internal/reflection-based invocation tricks.
