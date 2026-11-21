---
status: accepted
---

# Fragments Are Analyzed in Their Snapshot, Not Reparsed in Isolation

A fragment target (a scriptblock or AST node submitted via `-Script`) was reparsed from its own extent text, so every coordinate was fragment-local and a mapping layer (`GetSourcePosition`, `SourceLabel`, a `FixMode Off` fork in `Start-Nitpicking`) translated back to the host file for each consumer. Linters that embed one body of code in another take one of two paths: map coordinates back after analysis (ESLint processors, Razor `#line` directives) or parse the whole host and restrict analysis to a range (PSScriptAnalyzer `Invoke-Formatter -Range`, Prettier `--range-start/--range-end`, LSP range formatting). We chose the second: a fragment's document holds the complete snapshot it was parsed from (`Extent.StartScriptPosition.GetFullScript()`), `Ast` is the fragment's node located inside that snapshot, and only text within the fragment may be edited. Coordinates are therefore simply correct, with no translation anywhere. We chose this over mapping because the mapping cost is paid per consumer and fails silently (double-shifted offsets land on a plausible wrong line), while the snapshot cost is paid once at construction and fails loudly (fragment not found in snapshot). For a project with one maintainer, locality and loud failure outweigh the small cost of holding the host text.

## Consequences

- A fragment's snapshot may be far larger than the fragment; it is context, never a write target. `IsFileBacked` remains the sole write gate and is only set by `-Path`.
- Effective text returned to callers is the fragment's slice, not the snapshot; diff and reanalysis operate on the snapshot so a second analysis pass keeps absolute coordinates.
- `GetSourcePosition`, `SourceExtent`, `HasSourceProvenance`, `SourceLabel`, and the `FixMode Off` fork are retired; no coordinate-translation consumer remains.
- The snapshot is the parse-time text; later edits to the file on disk are not tracked, so editor navigation may land on stale lines. This was already true and is accepted.
- `Start-Nitpicking -Script` strings and `[scriptblock]::Create()` input have no host, so their snapshot equals the fragment and their behavior is unchanged.
