# Caret annotations for edit previews

Status: implemented. AstEditor supports opt-in `-Annotate`; Nitpick enables it
for correction proposal diffs. The design below records the agreed scope.

## Assessment and ownership

This is feasible as a bounded presentation change in AstEditor. Nitpick should
opt into it, not implement its own span calculation.

The existing pipeline already retains the required information:

- [Show-AstDiff](../Public/Show-AstDiff.ps1) sorts queued edits, selects their
  indexes, and builds source line records.
- [Get-AstDiffHunk](../Private/AstDiffing/Get-AstDiffHunk.ps1) groups edits into
  blocks and hunks while retaining each item's edit and sorted index.
- [Format-AstDiff](../Private/AstDiffing/Format-AstDiff.ps1) groups reasons for
  headers and renders complete original/replacement blocks.
- [Get-AstTextLine](../Private/Get-AstTextLine.ps1) supplies offsets separating
  line content from CRLF, LF, and CR terminators.
- Nitpick's [correction resolver](../../Nitpick/Public/Interface/Resolve-NitpickCorrectionProposal.ps1)
  stores `Show-AstDiff -Label Position -Annotate` output in `Proposal.Diff`. Its
  [correction formatter](../../Nitpick/Private/Formatting/Format-NitpickCorrection.ps1)
  indents that string; it need not calculate annotations.

Caret spans will describe **queued edit ranges**, not a newly computed
character-by-character difference. A producer replacing an entire statement or
function will therefore get a broad underline even if only one token differs.
Finding a minimal textual difference inside such replacements is a separate,
more substantial feature and is not needed for this proposal.

Different edits within an aggregate block already carry separate reasons. Keep
the existing reason headers, especially Nitpick's navigable `line:column reason`
headers. Carets narrow down the affected text without labels of their own.
A Nitpick change set and an AstEditor display block are not the same grouping;
display indexes do not become correction or rule identities.

## Agreed behavior

- Add opt-in `Show-AstDiff -Annotate`; no-switch output remains unchanged.
- Nitpick opts in when constructing `Proposal.Diff`.
- Keep hunk-header reasons, their existing grouping, and `-Label` behavior.
  AstEditor continues to create these headers; no separate header parameter is
  needed. `Position` retains the first edit's location for each distinct reason,
  not just the first reason in the hunk.
- Underline removed text beneath original (`-`) lines and added text beneath
  replacement (`+`) lines. A replacement has annotations on both sides.
- Use uncolored caret rows, including when removed lines are red and added
  lines are green. Existing `-NoColor` and `NO_COLOR` behavior remains intact.
- Use bare carets without indexes or inline reasons. Merge spans starting on
  the same displayed line into one annotation row, preserving gaps between
  them; there is no label-collision or stacking logic.
- For a multiline span, underline only its first line on the corresponding
  side, from the start column to the end of that line's covered content. This
  is a start-line annotation, not a claim to visualize the full multiline range.
- An insertion underlines its added text on `+` only; a deletion underlines its
  removed text on `-` only. Do not add an insertion-point caret on the other side.

### Preview

Two edits on one original line, with reasons retained above the block:

```text
[0] Remove unary negation
[1] Use -isnot
  1 | - -not ($Value -is [int])
    |   ^^^^         ^^^
    | +  ($Value -isnot [int])
    |            ^^^^^^
```

An insertion underlines the added text with neutral carets:

```text
[0] Add suffix
  1 | - $name = "hello"
    | + $name = "hello world"
    |                 ^^^^^^
```

With Nitpick's `-Label Position`, a header remains navigable and includes its
reason, for example `2:26  Use '[Parameter(Mandatory)]' instead of assigning it $true.`
The bare caret rows do not change that header format or establish a mapping
between individual reasons and spans.

These examples use the existing working-tree `|` gutter layout. Implementation
preserves that change and updates its old test expectations; annotation padding
shares the source-text origin without independently changing gutter formatting.

## Implementation approach

1. Thread `-Annotate` from `Show-AstDiff` into `Format-AstDiff`, defaulting off.
   Reuse block items and line records; leave hunk grouping, selection, reverse
   edit application, and document validation unchanged.
2. Render original and replacement lines individually when annotations are
   enabled, inserting each line's merged annotation row immediately below it.
   Reuse or narrowly extend
   [Add-AstDiffLine](../Private/AstDiffing/Add-AstDiffLine.ps1) so splitting,
   blank-line preservation, gutters, and color resets do not diverge. Keep
   source-line rendering and the no-switch path equivalent.
3. Original spans are the edits' nonempty `[StartOffset, EndOffset)` ranges.
   Compute replacement spans within each edited block in ascending edit order:
   its start is `StartOffset - BlockStartOffset + cumulativeDelta`, its length
   is `ReplacementText.Length`, and each edit changes the delta by replacement
   length minus original length. Use only selected block items, not unselected
   queued edits. This bookkeeping locates inserted text without searching for
   strings or comparing whole blocks.
4. For each nonempty span, locate its start line with the existing
   [offset lookup](../Private/AstDiffing/Get-AstLineIndexFromOffset.ps1).
   The shared line renderer obtains block-relative line records for each side.
   Clip the first-line span at `ContentEnd`; never underline a CR or LF as
   a printable character. Use one boundary caret for a nonempty span whose
   first-line portion contains only a terminator.
5. Use a blank line-number field and blank change marker on annotation
   rows, with the same source-text origin as the preceding `-` row. Construct
   indentation from the source prefix, mapping non-tab characters to spaces
   and preserving tabs. Do not measure ANSI-colored strings.
   Merge covered columns into one row per line, retaining prefix/inter-span tabs
   where possible rather than replacing all indentation with spaces.
6. Change Nitpick's proposal construction to
   `Show-AstDiff -Document $Document -Label Position -Annotate`.
   Keep the proposal/result contracts and correction lifecycle unchanged;
   consumers displaying the stored diff inherit the annotations.

### Boundary cases and limits

- **Empty document or insertion after a final terminator:** underline the added
  text on `+`; no original annotation anchor or placeholder removed line is needed.
- **Unterminated EOF insertion:** underline the added text at its computed
  position in the replacement line, not a point in the original line.
- **Blank line or newline removal:** use one caret at the boundary. It is a
  location marker, not a visible representation of the removed terminator.
- **Line joining and whole-line deletion:** keep the existing block expansion
  rules. Expanded neighboring text is not underlined merely because it appears
  in a changed block. Pure newline deletion has a boundary caret on `-`, not
  carets over unchanged text on the joined `+` line.
- **Tabs and Unicode:** preserving prefix tabs handles ordinary tab-indented
  code, but offsets count .NET UTF-16 units, not terminal display cells.
  Tabs inside the highlighted span, combining marks, and wide characters need
  display-width handling for exact visual underlines. Do not promise universal
  terminal alignment in this first version; document and test the limitation
  rather than silently describing carets as exact display-cell ranges.

## Validation and completion criteria

Before implementation tests, load the repository's `pwsh-test-runner` skill
and use [Invoke-Test.ps1](../../../../tools/Invoke-Test.ps1). Run targeted tests
first, with Windows PowerShell 5.1 as the compatibility gate.

- Extend [Show-AstDiff.Tests.ps1](../Tests/Public/Show-AstDiff.Tests.ps1) with
  exact annotation-mode output for deletion, insertion, replacement, merged
  edits, repeated reasons, both label modes, selected indexes, multiline edits,
  blank lines, terminator removal, and all three EOF insertion cases.
- Cover CRLF/LF/CR inputs, multi-digit gutters, tabbed prefixes, context/hunk
  boundaries, empty selections, and no queued edits.
- Assert caret placement against original and replacement columns, not just
  the presence of `^`. Include multiple length-changing edits on one line and
  inserted newlines that shift later replacement spans. Verify pure insertions
  and deletions annotate only their nonempty side and spans stop at gaps.
  Test color-enabled output as well as `-NoColor` and `NO_COLOR`: annotation
  rows contain no ANSI styling while existing source/header colors still work.
- Preserve no-switch exact-output expectations using the adopted `|` gutter.
  Both the private renderer and public diff baseline tests now expect that
  existing layout rather than hiding the difference with loose matches.
- Add focused Nitpick proposal/formatting integration coverage: reason headers
  and position prefixes remain unchanged and navigable, indentation preserves
  alignment, and preview/application trailers and correction counts do not change.
- Update public help, the AstEditor README, and Nitpick autocorrection docs when
  implementing the feature. Mark this design implemented only after those focused
  tests pass. No dependencies, new public edit types, or minimal-diff algorithm
  are required.
