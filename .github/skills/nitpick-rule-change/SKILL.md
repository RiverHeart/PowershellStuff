---
name: nitpick-rule-change
description: Use when adding, renaming, or changing a Nitpick rule, including AST analysis, identity, registration, corrections, tests, and documentation.
---

# Skill: Nitpick Rule Change

## Purpose

Use this skill for built-in rules under `src/modules/Nitpick`, including:

- Adding a diagnostic rule
- Changing a rule's applicability or AST traversal
- Adding or changing an automatic correction
- Renaming or recategorizing a rule
- Replicating a useful PSScriptAnalyzer rule as a Nitpick rule

## Inputs

Clarify these before editing:

- The defect or code pattern the rule detects
- Positive, negative, and intentional-use examples
- Rule name, category, severity, and expected message
- Whether nested scriptblocks should be analyzed
- Whether the rule is diagnostic-only or safely correctable
- PowerShell compatibility requirements

When replicating PSScriptAnalyzer behavior, preserve its useful intent and
observable edge cases, but do not copy implementation or blindly preserve
PSScriptAnalyzer false positives. Define Nitpick-native scope and suppression
behavior explicitly.

## Read First

Read enough of the existing domain and implementation to avoid inventing a
parallel contract:

1. `src/modules/Nitpick/CONTEXT.md`
2. The nearest built-in rule in the same category
3. The nearest rule with similar AST traversal or correction behavior
4. `src/modules/Nitpick/Nitpick.psd1`
5. `src/modules/Nitpick/Docs/MaintainerNotes.md` when package or identity
   behavior is relevant

Use these established terms:

- **Rule** for the check
- **Producer** for the rule's callable body
- **Coordinator** for discovery, selection, identity, and execution
- **Target**, **Snapshot**, and **Effective text** as defined by `CONTEXT.md`
- **Finding**, **Correction**, and **Text Edit** for analysis output and fixes

## Rule Placement and Shape

Place native rules in the matching category:

```text
src/modules/Nitpick/Public/Rules/<Category>/Test-<LocalName>.Rule.ps1
```

Use `Test-*` for the normal boolean/finding producer convention. Use `Measure-*`
only when the rule naturally measures target-wide properties. Follow existing
PowerShell formatting and comment-based help rules.

A built-in producer should:

1. Support the `ScriptBlockAst` and `Details` parameter sets.
2. Accept optional `IDictionary` context.
3. Derive `$RuleName` from the command's noun and use standalone identity
   `Nitpick/$RuleName`.
4. Return metadata from `-Details` without requiring a script AST.
5. Read `SearchNestedScriptBlocks` from `$Context.RuleBehavior`.
6. Default traversal to scope-local unless the caller opts into recursion.
7. Create findings with `New-NitpickFinding`.

Metadata must include:

- `Name`
- `CommandName`
- `Category`
- `Description`
- `Severity`
- `Explanation`

Use only supported categories: `Style`, `Quality`, `Security`, `Performance`,
`Maintainability`, `Correctness`, `Compatibility`, or `Other`.

## Rule Naming

The local name is part of the qualified `RuleId` and becomes a stable
suppression selector. Choose it for the rule's general effect, not the first
context or AST shape that motivated the implementation.

Name the violated invariant, risky outcome, or preferred invariant. Avoid
embedding incidental execution details, specific helper commands, or a narrow
scenario when the rule can apply elsewhere.

For example, prefer `PossibleTypeResolutionFailure` over
`AvoidNamespaceDependentTypesInSerializedScriptblocks`: a namespace-dependent
serialized scriptblock is one way the risk occurs, while failure to resolve a
type is the rule's actual concern. The narrower name would become misleading as
the producer recognizes additional failure contexts.

Treat common prefixes as meaningful signals:

- `Use<Invariant>` for a preferred representation or idiom, especially when
  the expected replacement is clear.
- `Avoid<Problem>` for a construct that should generally not be used, where the
  producer has enough evidence to prescribe against it.
- `Possible<Outcome>` for a rule that identifies a credible risk without proving
  the runtime outcome. Use it when extra intent, data, or environment
  information would be needed to establish certainty.

Do not use `Avoid` merely because a rule happens to find a pattern, and do not
use `Possible` as a generic placeholder for a weakly defined rule. The prefix
should communicate either recommendation strength or diagnostic confidence.
When neither applies cleanly, name the invariant or behavior directly.

## AST and Scope Analysis

Design AST matching from concrete examples rather than text matching.

- Prefer exact AST node types and relationships.
- Preserve trivia and source coordinates by reporting the smallest meaningful
  extent.
- Keep lexical scope explicit. A same-named variable in another scriptblock is
  not automatically the same declaration.
- Treat `RuleBehavior.SearchNestedScriptBlocks = $false` as scope-local
  traversal, not as a request to suppress analysis of the submitted function
  body.
- Avoid broad recursion inside helper searches when the rule has deliberately
  bounded scope.
- Report once per logical violation; deduplicate by stable extent or scope/name
  key when nested AST shapes overlap.
- Do not infer runtime command behavior that static AST evidence cannot prove.
- Exclude known intentional and automatic cases when the rule's semantics call
  for it.

Before editing, inspect ASTs for ambiguous constructs when needed. Probe a small
set of cases in a fresh PowerShell process instead of relying on assumptions.

## Identity and Findings

Native findings require a qualified `RuleId` in `Namespace/Name` form. Built-in
producers use:

```powershell
$RuleId = "Nitpick/$RuleName"
```

Pass the same ID to standalone findings and any nested corrections. During
coordinated execution, Nitpick replaces producer attribution with the executing
descriptor's identity. Never try to validate or override that coordinator-owned
behavior in the producer.

Use:

- `Information` for advisory intent or style guidance
- `Warning` for likely correctness or quality problems
- `Error` only for invalid or unusable constructs

Keep `Message` actionable and `Explanation` focused on why the pattern matters.

## Corrections

Prefer diagnostic-only output unless the fix is deterministic and evidence-based.

For correctable findings:

1. Create corrections with `New-NitpickCorrection`.
2. Give standalone corrections the same `RuleId` as the finding.
3. Use `New-AstTextEdit` or an AstEditor collection edit against the source
   snapshot.
4. Keep all replacements required for one resolution in one correction's
   `TextEdits`; edits in one correction are atomic.
5. Keep distinct possible resolutions as separate corrections; never merge
   alternatives.
6. Mark applicability `Safe`, `Review`, or `Unsafe` according to the repository
   correction contract.
7. Revalidate generated edits through
   `Resolve-NitpickCorrectionProposal`.

Do not automatically rewrite source when variable flow, runtime types, intent,
or formatting policy cannot be proven from the AST.

## Registration and Discovery

For a built-in Nitpick rule, update both manifest surfaces in
`src/modules/Nitpick/Nitpick.psd1`:

1. Add the exported function to `FunctionsToExport`.
2. Add the same function to `PrivateData.Linting.Rules`.

Keep the entries alphabetically grouped with the existing rule lists.

Renames have no compatibility alias. Rename the producer, update both manifest
lists, update every qualified `Nitpick/<LocalName>` reference, and let old
selectors stop resolving.

## Tests

Add a focused Pester file under the matching test category:

```text
src/modules/Nitpick/Tests/Public/Rules/<Category>/Test-<LocalName>.Tests.ps1
```

Test behaviors, not implementation details. At minimum cover:

- Representative positive cases
- Important negative and intentional-use cases
- Scope and nested-scriptblock traversal
- Multiple findings and deduplication where applicable
- `-Details` metadata
- `Find-Nitpick` discovery
- Coordinated execution through `Start-Nitpicking`
- Rule-ID attribution
- Native suppression with an exact qualified rule ID
- Correction proposal or no-correction behavior, as appropriate
- Any correction reanalysis and candidate-text expectations

When a rule is responsible for standalone corrections, also verify that
coordinated identity replaces IDs on both findings and nested corrections.

Avoid broad Pester mocks when parsing and direct AST invocation are sufficient.

## Documentation

Update directly related documentation:

- Update the built-in rule count in `src/modules/Nitpick/README.md` when the
  number changes.
- Update examples or maintainer notes when the rule introduces a new reusable
  pattern or observable contract.
- Update `CONTEXT.md` only when the canonical language changes. Do not place
  implementation detail there.
- Add an ADR only for a hard-to-reverse tradeoff that future maintainers would
  otherwise find surprising.

Do not update documentation solely to narrate implementation internals that are
clear from the rule and tests.

## Validation

Load the `pwsh-test-runner` skill before running tests.

Run focused tests first:

```powershell
./tools/Invoke-Test.ps1 `
    -Suite Nitpick `
    -Path "Tests/Public/Rules/<Category>/Test-<LocalName>.Tests.ps1" `
    -ExitOnError
```

For a compatibility-sensitive rule, run the same focused tests in Windows
PowerShell 5.1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./tools/Invoke-Test.ps1 `
    -Suite Nitpick `
    -Path "Tests/Public/Rules/<Category>/Test-<LocalName>.Tests.ps1" `
    -ExitOnError
```

After focused tests pass:

1. Lint changed PowerShell files with the repository settings.
2. Run `git diff --check`.
3. Run the full Nitpick suite:

```powershell
./tools/Invoke-Test.ps1 -Suite Nitpick -ExitOnError
```

Do not run coverage unless explicitly requested. Treat PowerShell 5.1 failures
as compatibility failures, not optional noise.

## Guardrails

- Do not put implementation details in `CONTEXT.md`.
- Do not duplicate PSScriptAnalyzer identity fields; native RuleId is the
  only identity.
- Do not infer a namespace or allow producer code to override coordinator
  attribution.
- Do not make a rule enabled by default without adding it to both manifest
  registration lists.
- Do not add a risky correction to make a diagnostic rule appear complete.
- Do not hide rule errors with broad catches, silent defaults, or
  success-shaped fallbacks.
- Do not modify unrelated suppression attributes while adding a replacement
  Nitpick rule.

## Completion Criteria

- Rule behavior is defined by focused positive and negative cases.
- Producer, metadata, identity, and traversal contracts are satisfied.
- The rule is discoverable and runs through the coordinator.
- Corrections, if any, are atomic and validated.
- Suppression works by qualified RuleId.
- Manifest export/default registration and related docs are synchronized.
- Focused tests and the full Nitpick suite pass without new failures.
