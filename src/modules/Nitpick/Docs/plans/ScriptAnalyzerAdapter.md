# PSScriptAnalyzer Adapter

## Status

Implemented. This document records the accepted scope and acceptance criteria
for separating Nitpick from PSScriptAnalyzer.

## Context

Nitpick's rule producers currently implement two output contracts: native
`NitpickFinding` output for the coordinator and PSScriptAnalyzer
`DiagnosticRecord` output for custom-rule hosting. That coupling reaches rule
bodies, helper APIs, finding/correction conversion methods, tests, and module
imports. It also makes PSScriptAnalyzer a debugging prerequisite in the VS Code
PowerShell extension even when only native Nitpick behavior is under test.

PSScriptAnalyzer compatibility remains useful, but it should be an optional
integration boundary rather than a rule-authoring concern.

## Blueprint

- Add an optional sibling module named `Nitpick.ScriptAnalyzer`.
- The adapter imports Nitpick and PSScriptAnalyzer. Nitpick does not import the
  adapter or PSScriptAnalyzer.
- At adapter import time, discover Nitpick's built-in rule descriptors and
  dynamically export one PSScriptAnalyzer-compatible `Test-<LocalName>`
  command per descriptor.
- Generated wrappers delegate invocation, metadata, settings, applicability,
  identity assignment, and dispatch-shape handling to `NitpickRule`; they do
  not reimplement rule logic.
- Native producers and coordinator calls use only `NitpickFinding` and
  `NitpickCorrection` objects. Output selection for
  `DiagnosticRecord`/`CorrectionExtent` is removed from native helpers.
- PSScriptAnalyzer conversion lives only in the adapter. A native finding
  becomes one diagnostic, and single-edit corrections become suggested
  corrections. A multi-edit atomic Nitpick correction is omitted rather than
  split into independently applicable edits.
- Wrappers preserve scope-local traversal so PSScriptAnalyzer-hosted nested
  scriptblocks are reported once.
- PSScriptAnalyzer custom-rule consumers use the adapter manifest; direct
  `-CustomRulePath` use of `Nitpick.psd1` is intentionally removed.
- PSScriptAnalyzer-specific tests move into the adapter module's suite. The
  Nitpick suite runs without importing PSScriptAnalyzer.

## Acceptance Criteria

- Importing and testing Nitpick does not require PSScriptAnalyzer to be loaded.
- Native Nitpick rule code contains no PSScriptAnalyzer types, output modes, or
  conversion calls.
- `NitpickFinding` and `NitpickCorrection` contain no PSScriptAnalyzer
  conversion methods or type references.
- `Nitpick.ScriptAnalyzer` dynamically exposes every rule listed as a built-in
  Nitpick rule in the Nitpick manifest.
- `Get-ScriptAnalyzerRule`, `Invoke-ScriptAnalyzer`, nested-scope deduplication,
  metadata, settings, and diagnostics work through the adapter.
- Single-edit corrections survive adapter conversion, while multi-edit
  corrections are omitted atomically.
- The Nitpick Pester suite and the adapter Pester suite pass independently.
- User-facing module documentation and the superseding ADR explain the new
  integration boundary and the intentional `CustomRulePath` breaking change.
