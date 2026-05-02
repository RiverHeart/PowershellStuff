---
name: wpf-dsl-keyword-change
description: Use this skill to add, rename, or change behavior of a WPF DSL keyword, ensuring code, tests, and docs are updated together.
---

# Skill: WPF DSL Keyword Change

## Purpose

Use this skill when adding, renaming, or changing behavior of a WPF DSL keyword in this repository.

## Inputs

- Keyword name
- Intended syntax
- Expected parent-child behavior
- Whether behavior is breaking or additive

## Workflow

1. Update or add the keyword function under src/modules/WPF/Public/DSL.
2. Keep trailing scriptblock pattern and $this-based configuration behavior.
3. Ensure auto-attach and return semantics match existing control patterns.
4. If lookup/event/style behavior is affected, update related helpers.
5. Check `src/modules/WPF/Private/Update-WPFObject.ps1` — for example, if the new keyword is a container that accepts Shape children (e.g. Path), add a branch in the Shape handler to assign children to the correct property (e.g. `Border.Child`, `Button.Content`). Without this, objects nested inside the keyword's scriptblock may be ignored or not attached correctly.
6. Export new public functions by adding them to `FunctionsToExport` in `src/modules/WPF/WPF.psd1`.
7. Add or update tests in src/modules/WPF/Tests.
8. Update docs in src/modules/WPF/Docs/KeywordReference.md.

## Validation

Run:

```powershell
Invoke-Pester -Path "src/modules/WPF/Tests" -Output Detailed
```

## Guardrails

- This project is experimental. Breaking changes are allowed and preferred over backward-compatible workarounds that accumulate technical debt. Do not add aliases or shims to preserve old names — rename cleanly and update all call sites.
- Avoid changing DSL contract unless explicitly requested.
- Preserve naming and param formatting conventions used by existing DSL functions.
- Keep keyword behavior and validation in dedicated helper keywords/functions; use `Update-WPFObject` primarily for composition/routing.
- Prefer additive changes over broad refactors.

## Completion Criteria

- Tests pass
- Function is exported (if public)
- Keyword reference updated
- No new parse or analyzer errors in touched files
