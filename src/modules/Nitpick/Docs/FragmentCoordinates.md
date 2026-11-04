# Plan: Snapshot-absolute coordinates for fragment targets

Status: **snapshot-backed implementation and Nitpick integration complete; compatibility cleanup pending.**
Decision record: [ADR 0004](adr/0004-fragments-are-analyzed-in-their-snapshot.md).
Terms (fragment, snapshot, target, effective text) are defined in [CONTEXT.md](../CONTEXT.md)
and used here with those meanings. Avoid "scope" — this plan originally used it for what
the glossary calls a fragment.

## Decisions

Resolved with the owner on 2026-11-04. Each is a constraint on the implementation, not a
suggestion.

| # | Decision | Rejected alternatives |
| --- | --- | --- |
| D1 | `AstDocument.Ast` is the **fragment's node** (what the caller handed in). New `Root.Ast` is the snapshot root. | `Ast` = root with a separate `ScopeAst`. Rejected because `Edit-PSFunction`, `Split-PSFunction`, `Extract-AstFunction`, and `New-AstCollectionEdit` all read `Document.Ast` as "the thing you gave me"; root-as-`Ast` would silently widen them to the host file. |
| D2 | **Snapshot text everywhere internally**: `AstDocument.OriginalText`, `Resolve-AstDocument.RenderedText`, `Proposal.OriginalText`, `Proposal.CandidateText`. **`Report.EffectiveText` is the fragment's slice**, including the `NoChanges` fallback. Invariant: every **snapshot-scoped** text on a document or proposal shares `Root.Ast`'s coordinate system; the only fragment-scoped texts are those named `*FragmentText` and `Report.EffectiveText`. | Fragment slice everywhere (reanalysis would reparse the slice and reintroduce fragment-local coordinates). Snapshot everywhere including `EffectiveText` (visible change: `-Script { } -FixMode Apply -Output Object` would return the host file). |
| D3 | Edits outside the fragment are **rejected by AstEditor** in `Add-AstTextEdit` with `FailureKind = 'OutsideTarget'`; the resolver records the whole batch as skipped, exactly like `Conflict`. Mandatory, not optional: reanalysis relocation (D6) is only sound if every edit is inside the fragment. | Reject only the offending correction; allow host edits. |
| D4 | **Snapshot parse errors positioned strictly before the fragment's `StartOffset` are filtered** from findings, with no warning; everything at or after the fragment's start is reported. An error before the fragment provably was not caused by it; an error after it might have been (the parser places "unclosed" errors at the opening token, at EOF, or elsewhere depending on the construct — verified, not predictable), so "inside the fragment extent" is **not** a safe filter. Relocation succeeding is **not** a safety net: a fragment with an unclosed brace relocates fine with its extent swallowed to EOF. **Render-validation parse errors are never filtered.** | Filtering to the fragment's extent (hides a broken fragment whose error lands at EOF — the original D4, revised 2026-11-04). An errors-only reparse of the fragment text as a "broken?" oracle (precise, but a second parse and a reparse of fragment text, which the ADR retires). One `Write-Warning` per target. Reporting everything unfiltered. |
| D5 | Snapshot = `Extent.StartScriptPosition.GetFullScript()`. **Null → fall back to `Extent.Text`** (snapshot == fragment, today's behavior; hand-built `ScriptExtent` returns null). **Non-null but `Substring(StartOffset, Length) -cne Extent.Text` → throw.** Locate the fragment by the **input node's own type**, exact `StartOffset`/`EndOffset`, **and nesting depth** (count of `.Parent` hops to the root); zero or multiple matches → throw. Depth is required: a file that is exactly `{ … }` has a root `ScriptBlockAst` and an inner `ScriptBlockAst` with identical type and extent (verified: 2 hits without depth, 1 with). `AstDocument` accepts any `Ast`; Nitpick `-Script` keeps requiring `ScriptBlockAst` via `ScriptBlockAstTransform`. | Hard-coding `ScriptBlockAst` in the locate predicate; type + offsets alone; throwing on null `GetFullScript()`. |
| D6 | After rendering, relocate the fragment in the rendered snapshot at the same `StartOffset` (stable because of D3) with `EndOffset = StartOffset + OriginalLength + NetDelta`, matching on type **and depth** as in D5 (edits inside the fragment cannot change its ancestors). **The reanalysis parse passes `Document.Ast.Extent.File` as the parser file name** so candidate findings keep `Extent.File` and `NitpickRule.Invoke`'s `Context.File` is identical across passes. Failure → `FailedValidation`. | Reparsing the candidate as a bare string (today's `New-AstDocument -InputObject $CandidateText`), which drops `File` on the second pass only. |
| D7 | Text header for a fragment with a file is **two lines**: `(fragment, lines N–M)` on its own line **above** the bare path. Without a file: `<ScriptBlock>`, unchanged. `-SourceLabel` removed. `r:c` cells are OSC 8 links and never depended on the header. | `<path> (fragment, lines N–M)` on one line, or the annotation as a prefix — both **verified to break VS Code's native path-link detection** (2026-11-04). Path only (indistinguishable from a whole-file result, implying the rest of the file is clean). |
| D8 | **Path filters do not apply to fragments.** `-IncludePath`/`-ExcludePath` filter resolved file targets and `Rule.AppliesToPath` receives `$null` for the Script set, exactly as today — even though every file-sourced fragment will now carry `Ast.Extent.File` in every fix mode. A submitted fragment is explicit; path filters narrow a file *search*, and no search happened. Implementers: do not "fix" `$TargetPath` to read `Ast.Extent.File`. | Applying rule path predicates only (`AppliesToPath` gets `Extent.File`); treating a file-sourced fragment like a file target for all path filtering. Both rejected because the caller can `-ExcludeRule`, and strings/console fragments would still bypass the filters, making the behavior depend on where a scriptblock happened to come from. |
| D9 | `Document.Tokens` is **filtered to the fragment's extent**; `Root.Tokens` holds every snapshot token, mirroring `Ast`/`Root.Ast`. `Extract-AstFunction` and `New-AstFunctionRewritePlan` read `Tokens` to find comments near functions and must not attach a host comment to a fragment function; comment-based suppression ([ADR 0002](adr/0002-comment-based-rule-suppression.md)) has the same need. | Leaving `Tokens` as all snapshot tokens. |
| D10 | Group complete snapshot parse data under a **typed `Document.Root` object** with `Ast`, `Tokens`, and `ParseErrors`. Unprefixed `Document.Ast`, `Tokens`, and `ParseErrors` describe the submitted target (parse errors use D4's conservative rule). Non-fragments share the same parse data in both views. | Flat `RootAst`/`RootTokens` plus `FragmentParseErrors`: asymmetric defaults made it unclear which view a property described. An untyped hashtable or PSCustomObject: these three stable members benefit from explicit types. |

## Problem

This section describes the behavior before implementation.

`Start-Nitpicking -Script` accepts a `ScriptBlock` or `ScriptBlockAst` that may be a
*fragment* of a larger source: a scriptblock literal inside a `.ps1`, a nested block
found with `Ast.Find`, or a block typed into the console. When any fix mode is active,
[New-AstDocument](../../AstEditor/Public/New-AstDocument.ps1) builds the `AstDocument`
by **reparsing the fragment's `Extent.Text` in isolation**, so every coordinate in the
document — AST extents, tokens, parse errors, text edits, finding `ViolationExtent`s,
diff labels — is relative to the fragment, with line 1 being the fragment's first line
and `Extent.File` null.

Consequences before implementation:

- Finding positions in text output are fragment-local and cannot be hyperlinked.
  `Format-NitpickText` prints `<ScriptBlock> from C:\x.ps1:12:3` as a header hint only.
- `-FixMode Off` and fix modes report **different coordinates for the same input**:
  `Start-Nitpicking` passes the original AST to rules when `FixMode -eq 'Off'` but the
  reparsed `Document.Ast` otherwise (the former fix-mode fork in
  [Start-Nitpicking.ps1](../Public/Interface/Start-Nitpicking.ps1)).
- A mapping layer exists solely to undo the reparse: `AstDocument.SourceExtent`,
  `HasSourceProvenance()`, `GetSourcePosition(offset)` in
  [AstEditor.psm1](../../AstEditor/AstEditor.psm1); `Proposal.SourcePath`;
  `Format-NitpickText -SourceLabel`; the `Get-TestSourceExtent` test helper. It works for
  guided navigation but every new consumer must know whether an offset is fragment-local
  or snapshot-absolute, and passing the wrong kind double-shifts silently.

## Key fact that makes the fix possible

`IScriptExtent` does not expose the full source, but `IScriptPosition` does:

```powershell
$Full = $Ast.Extent.StartScriptPosition.GetFullScript()
```

Verified 2026-11-04 on PowerShell 7.6.9 and Windows PowerShell 5.1.19041 (identical results):

| Input | `Extent.File` | `GetFullScript()` | `Fragment.Text -ceq Full.Substring(StartOffset, Length)` |
| --- | --- | --- | --- |
| Nested block in a parsed file | file path | whole file text | true |
| `{ ... }` literal in a dot-sourced file | file path | whole file text | true |
| `{ ... }` typed at the console | null | whole command input | true (StartLine was 14, not 1) |
| `[scriptblock]::Create($text)` / string | null | the text itself | true, StartOffset 0 |
| `(Get-Command Foo).ScriptBlock.Ast` | file path | whole file text | true — but the node is a `FunctionDefinitionAst`, not a `ScriptBlockAst` (drives D5's "match on input type") |
| `{}` (empty block) | per host | per host | true, two-character extent; empty standalone text instead has a zero-length root |
| Hand-built `[ScriptExtent]` | null | **null** | n/a (drives D5's fallback) |

Relocation: parsing `GetFullScript()` with `Extent.File` as the parser file name and
running `FindAll` for the input's type at the input's exact offsets returned exactly one
node in every file-backed case above, with the correct `File` and `StartLineNumber`.

So the original AST's offsets are already absolute into `GetFullScript()`. The reparse
is what throws that away. Parse the **snapshot** instead, and locate the fragment's
node inside the new root.

## Why this path (summary of ADR 0004)

Two families exist for analyzing code embedded in a larger body. **Map back after
analysis** (ESLint processors, Razor `#line`, Volar source maps) is what Nitpick does
today; its cost is paid per consumer and it fails silently when an offset is shifted
twice. **Parse the host, restrict to a range** (`Invoke-Formatter -Range`, Prettier
`--range-*`, LSP range formatting) pays once at construction and fails loudly when the
fragment cannot be located. With a single maintainer, locality and loud failure win.

## Design

### AstEditor

`AstDocument` becomes a **snapshot** that may carry a **fragment**.

- `OriginalText` becomes `GetFullScript()` for `ScriptBlock`/`Ast` input, with the D5
  fallback and mismatch check. The construction parse passes `Extent.File` (possibly null) as the
  parser file name so `Ast.Extent.File` and line numbers are correct. **`Path` stays
  `<memory>` and `IsFileBacked` stays
  `$false`** — the parser file name is provenance, not a write target. Document this
  split explicitly; it is the one place the two concepts could be confused.
- **(D1)** `Ast` is the fragment's node inside the reparsed snapshot, located per D5:
  compute the input's depth (`.Parent` hops to the root), then
  `Root.Ast.FindAll({ $_.GetType() -eq $Input.GetType() -and $_.Extent.StartOffset -eq $Input.Extent.StartOffset -and $_.Extent.EndOffset -eq $Input.Extent.EndOffset -and (depth of $_) -eq $Depth }, $true)`,
  expecting exactly one hit. `Root.Ast` is the snapshot root (D10). For
  `-Path`, strings, and whole-snapshot ASTs, `Ast` and `Root.Ast` are the same node.
  Expose `[bool] IsFragment` (`Ast` is not `Root.Ast`) so callers do not compare
  references. Note `IsFragment` is about identity, not coverage: a
  `FunctionDefinitionAst` spanning an entire file is a fragment that covers every byte.
  Tests must not assert `IsFragment -eq $false` for "whole-file" inputs generically.
- **(D9/D10)** `Tokens` is filtered to `Ast.Extent`; `Root.Tokens` holds all
  snapshot tokens. Fragment token selection descends into
  `StringExpandableToken.NestedTokens` when necessary, so fragments inside string
  interpolation retain their comments and syntax tokens. `Root.Tokens` keeps the
  parser's original structure. For non-fragments they are the same array.
- Edits are validated against `OriginalText` exactly as now. Because rule-produced
  extents are now absolute, no offset translation is needed anywhere.
- **(D3)** `Add-AstTextEdit` rejects any edit not fully inside `Ast.Extent` when
  `IsFragment`, throwing with `Exception.Data['FailureKind'] = 'OutsideTarget'` in the
  same shape as `Conflict` and `ExpectedTextMismatch`.
- **(D2)** `Resolve-AstDocument -PassThruText` keeps `RenderedText` as the rendered
  snapshot. Add `RenderedFragmentText` (the fragment's slice, computed via D6) so
  consumers never slice by hand. For non-fragments the two are equal.
- **(D4/D10)** `ParseErrors` contains every snapshot error whose
  `Extent.StartOffset -ge Ast.Extent.StartOffset`, so Nitpick does not implement the
  rule itself. `Root.ParseErrors` keeps all snapshot errors.
- Remove `SourceExtent`, `HasSourceProvenance()`, `GetSourcePosition()` once no
  consumer remains. Provenance is simply `Ast.Extent.File`.

### Nitpick

- `Start-Nitpicking`: always invoke rules on `$Document.Ast` (now the fragment node).
  Delete the `FixMode -eq 'Off'` special case and its `WARNING` comment. Both modes now
  report the same coordinates. **(D4)** Build `PowerShellParseError` findings from
  `Document.ParseErrors`, not `Document.Root.ParseErrors`. **(D8)** `$TargetPath` stays
  `$null` for the Script set; do not read `Ast.Extent.File` into it.
- `Resolve-NitpickCorrectionProposal`:
  - **(D3)** Map `FailureKind 'OutsideTarget'` to the skip reason
    `"AstEditor rejected the target because an edit falls outside the submitted fragment."`
    alongside the existing `Conflict` and `ExpectedTextMismatch` branches.
  - **(D6)** Reanalysis must run on the **rendered fragment node**, not the rendered
    root, or rules would report findings from the rest of the file. Parse the rendered
    snapshot with `Document.Ast.Extent.File` as the parser file name (replacing today's
    bare `New-AstDocument -InputObject $CandidateText` for non-file-backed documents).
    Then re-locate the fragment in the candidate AST at the same `StartOffset` with
    `EndOffset = StartOffset + OriginalFragmentLength + NetDelta`, where
    `NetDelta = Σ(ReplacementText.Length − (EndOffset − StartOffset))` over accepted
    edits, matching on type and depth as in D5. If the match fails, treat it like a
    render parse error (`FailedValidation`) rather than analyzing the wrong node.
    **Render-validation parse errors are never filtered (D4).**
  - **(D2)** `Proposal.OriginalText` and `Proposal.CandidateText` are snapshot text.
    Add `Proposal.CandidateFragmentText` (from `RenderedFragmentText`) and
    `Proposal.OriginalFragmentText` (`Document.Ast.Extent.Text`).
  - `Proposal.SourcePath` is derived from `Document.Ast.Extent.File`; keep the field,
    drop the `SourceExtent` dependency.
- `Resolve-NitpickTargetCorrection` **(D2)**: `Report.EffectiveText` uses the fragment
  texts for fragments — `CandidateFragmentText` when `UseCandidateText`, otherwise
  `OriginalFragmentText`. File targets are unchanged. The `NoChanges` path goes through
  the same selection so a no-op fix never returns the host file.
- `Select-NitpickGuidedCorrection`: use `Finding.ViolationExtent` directly for
  `SetSelection`; delete the `GetSourcePosition` calls and the provenance branch. The
  `$PSEditor` guard and `try/catch` stay.
- `Format-NitpickText` **(D7)**: findings for a fragment from a file now have
  `Extent.File`, so positions hyperlink exactly as for `-Path`. When
  `Document.IsFragment` and a file exists, the header is two lines — `(fragment, lines
  N–M)` above the bare path — because any text on the path's line breaks VS Code's
  native link detection. `<ScriptBlock>` otherwise. Remove `-SourceLabel`. The
  formatter needs to know the fragment span — pass the fragment extent (or the
  document) rather than only `-Ast`.
- `Show-AstDiff`: Nitpick calls it with the default `-Context 0`, so only edited lines
  print and, by D3, those are all inside the fragment. Line labels become snapshot line
  numbers, which is the point. No clamping work is needed unless `-Context` is ever
  raised; if it is, clamp to the fragment's lines.

### Console input

`GetFullScript()` for a console scriptblock is the whole submitted command text and
`File` is null. Treat it like a string: coordinates are relative to that input, which
matches PowerShell's own error positions. Nothing to navigate to; nothing to special-case.
`EffectiveText` still returns the fragment slice (D2), so a user never sees their own
`Start-Nitpicking -Script { … }` command line echoed back.

## Invariants to preserve

- Fragments are **never written**. `IsFileBacked` is only set by `-Path`. A
  document that knows its source file is not thereby eligible to save to it. Add a test
  that proves a nested fragment from a file, under `-FixMode Apply`, leaves the file
  byte-identical (one exists today in `Start-Nitpicking.Fix.Tests.ps1`; keep it).
- Only text inside the submitted fragment may change. Enforced by the mandatory
  `Add-AstTextEdit` check (D3) and asserted by a test.
- `OriginalFingerprint` continues to hash `OriginalText` (now the snapshot). It is
  only compared on save, which fragments never do, so this is harmless — but note it.
- Snapshot parse errors strictly before the fragment are filtered from findings (D4);
  errors at or after its start, and all render-validation parse errors, are reported.
- Every snapshot-scoped text property on a document or proposal shares `Root.Ast`'s
  coordinate system (D2). The only fragment-sliced texts are the ones explicitly named
  `*FragmentText` and `Report.EffectiveText`.
- Path filters never apply to fragments (D8).

## Edge cases to test

1. Fragment on line 1, column > 1 (`& { param(...) }` on the first line) — column
   offsets on the first line are the classic off-by-one spot.
2. Fragment whose first edit starts exactly at `Ast.Extent.StartOffset` (a rule
   rewriting the entire scriptblock) — fragment relocation by `StartOffset` must still
   work.
3. Fragment containing a nested scriptblock that also has findings — rules already run
   with `SearchNestedScriptBlocks = $true`; ensure findings inside the nested block are
   kept and findings outside the fragment are not produced.
4. Two fragments from the **same file** submitted through separate `-Script`
   invocations — each gets its own document and the file is still never written.
   Adding pipeline binding to `-Script` is not part of this change.
5. `[scriptblock]::Create($text)` and plain strings — behavior must be byte-identical to
   today (StartOffset 0, no file).
6. A file with CRLF where the fragment is mid-file — `NewLineSequence` detection now
   sees the whole file, which is more correct, but check the diff rendering.
7. Reanalysis after a correction that changes the fragment's length — fragment end
   offset recomputed from `NetDelta`.
8. Fragment from a file that was **modified on disk** after the scriptblock was
   created — `GetFullScript()` is the parse-time text, not the current disk contents.
   Navigation may land on stale lines; this is acceptable and already true today.
   Document it.
9. `{ }` literal spanning the **entire file** — root and inner `ScriptBlockAst` share
   type and extent (`0–N`, verified); nesting depth disambiguates (D5). This is the
   `New-TestSourceDocument -Nested` fixture shape, so it is common, not exotic.
10. `FunctionDefinitionAst` input to `New-AstDocument` — located by its own type (D5);
    still rejected at Nitpick's `-Script` door with today's transform error. If it
    spans the whole file, `IsFragment` is still `$true`.
11. Hand-built `[ScriptExtent]` (null `GetFullScript()`) — falls back to `Extent.Text`;
    `IsFragment` is false and behavior equals a string input (D5).
12. Corrupt extent (`GetFullScript()` non-null but substring differs) — throws (D5).
13. Rule emits an edit outside the fragment — batch rejected with the `OutsideTarget`
    skip reason; the fragment is unchanged; reanalysis does not run (D3).
14. Host with a parse error **before** the fragment that does not damage it (stray `}`
    on line 1, fragment on line 4) — fragment relocates, no `PowerShellParseError`
    finding (D4).
15. Host with a parse error **after** the fragment (stray `}` on line 40) — reported as
    a `PowerShellParseError` finding, because it may have been caused by the fragment
    (D4; accepted over-report).
16. Host with a parse error that **does** damage the fragment (unclosed here-string
    before it) — relocation fails and throws with a clear message (D4/D5).
17. Fragment that is itself broken (unclosed brace inside it, from `ParseFile` + `Find`
    on a broken file) — relocates (extent swallowed to EOF, verified) and the error is
    reported, wherever the parser positioned it (D4).
18. Correction that leaves the fragment unparseable (unclosed brace) — the render error
    is reported wherever the parser places it and still fails validation (D4).
19. Empty fragment `{}` — its two-character extent relocates and produces no findings.
20. `-FixMode Off` and `-FixMode Preview` on the same fragment produce findings with
    identical `ViolationExtent` file/line/column, and candidate findings after
    reanalysis carry the same `Extent.File` as original findings (D6).
21. Text output: `(fragment, lines N–M)` on the line above the bare path; `r:c` cells are
    OSC 8 links; verify manually in VS Code's terminal and Windows Terminal that the path
    line and the position cells both remain clickable (D7).
22. `-Output Object` on a console fragment: `Report.EffectiveText` is the fixed
    scriptblock text, never the command line that invoked Nitpick (D2).
23. `-IncludePath`/`-ExcludePath` and a rule with a path predicate, run against a
    fragment from a non-matching file — the fragment is still analyzed (D8).
24. `Extract-AstFunction` on a fragment whose host has a comment immediately before the
    fragment — the comment is not attached to the fragment's function (D9).
25. Fragment inside an expandable string's interpolation — nested tokens and
    comment-based help remain available without exposing host comments (D9).

## Implementation checkpoint

- Steps 1–3 below are implemented together, including typed `Root`, confined edits,
  fragment-only effective text, source-preserving reanalysis, and the two-line header.
- Full validation passed on PowerShell 7 and Windows PowerShell 5.1:
  AstEditor **206/206** on each; Nitpick **612/612** on PowerShell 7 and **610/610**
  on Windows PowerShell 5.1.
- Compatibility cleanup remains: `SourceExtent`, `HasSourceProvenance()`,
  `GetSourcePosition()`, and their remaining tests/fixtures. Nitpick no longer needs
  coordinate translation; the retained lookup is an identity lookup.
- Automated tests verify header shape and OSC 8 destinations. Actual terminal
  click-through from edge case 21 remains a manual check.

## Removal checklist (after the above lands)

- `AstDocument.SourceExtent`, `HasSourceProvenance()`, `GetSourcePosition()` and their
  README paragraph in [AstEditor/README.md](../../AstEditor/README.md); the pointer
  comment above them in `AstEditor.psm1`.
- `Format-NitpickText -SourceLabel` and the `$SourceLabel` block in `Start-Nitpicking`.
- `GetSourcePosition` usage in `Select-NitpickGuidedCorrection`.
- `Get-TestSourceExtent` in `Tests/Support/CorrectionFixtures.ps1` (keep
  `New-TestSourceDocument -Nested`; it becomes the primary fixture for these tests).
- Tests in `AstEditor/Tests/Public/New-AstDocument.Tests.ps1` that assert
  fragment-local coordinates or `SourceExtent` reference identity; replace with
  assertions on `Root.Ast`/`IsFragment` and absolute `Extent.File`/line numbers.
- README "Guided navigation" paragraph in [Nitpick/README.md](../README.md) about
  fragment-local previews.
- The fragment-coordinates paragraph in `MaintainerNotes.md` (it describes the
  limitation this plan removes).
- `New-AstDocument` help text describing fragment-local reparse.

## Suggested order

Steps 1 and 2 (including the header/navigation wiring from step 3) must land together.
Keeping `GetSourcePosition` as an identity lookup does not preserve old Nitpick
reporting: without step 2 it returns the host snapshot as effective text and reanalyzes
the host rather than the fragment. This was confirmed by targeted integration tests.

1. AstEditor: snapshot parse + typed `Root`/`IsFragment` (D10) + `Tokens`/`Root.Tokens` (D9) +
   file-name-as-provenance + D5 fallback/mismatch/depth + `OutsideTarget` check +
   `RenderedFragmentText` + target-level `ParseErrors`, with `New-AstDocument` tests for the
   table above and edge cases 9–14, 16–17, 19, 24. Keep `GetSourcePosition` working
   as an identity lookup until its remaining compatibility tests and fixtures migrate.
2. Nitpick: rules on `Document.Ast`; delete the `FixMode -eq 'Off'` fork;
   `OutsideTarget` skip reason; D6 reanalysis with file name; D2 `*FragmentText` and
   `EffectiveText` slicing; D4/D10 `ParseErrors`; D8 leave `$TargetPath` alone.
   Run the full Nitpick suite — the `Start-Nitpicking.Fix` and
   `Autocorrection.Contracts` suites are the ones most likely to encode fragment-local
   expectations.
3. Simplify consumers: `Select-NitpickGuidedCorrection`, `Format-NitpickText` (D7),
   `Proposal.SourcePath`.
4. Removal checklist; update `MaintainerNotes.md`. `CONTEXT.md` and ADR 0004 are
   already current.

Run tests with `./tools/Invoke-Test.ps1 -Suite AstEditor` and `-Suite Nitpick`, on both
`pwsh` and `powershell.exe` — the `ScriptBlockAstTransform` and `GetFullScript()` paths
must behave identically on 5.1 (the probes above already did).

## Non-goals

- Tracking subsequent edits to the file after analysis (stale navigation is accepted).
- Making fragment input writable. If that is ever wanted it is a separate feature with
  its own `ShouldProcess` and fingerprint story, not a side effect of this change.
- Letting rules edit the host outside the fragment. A rule that needs the host should
  be run against the file with `-Path`.
