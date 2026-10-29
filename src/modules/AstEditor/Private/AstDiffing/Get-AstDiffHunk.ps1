using namespace System
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Groups selected edits into changed-line blocks and context-connected hunks.

.DESCRIPTION
    Groups selected edits into changed-line blocks and context-connected hunks.

    A block contains StartLine, EndLine, and Items (each with Index and Edit).
    Its adjacent changed lines are rendered as one original/replacement pair.
    A hunk is a list of blocks whose context touches or overlaps. Returns the
    outer list without enumeration to preserve empty and single-hunk results.

.NOTES
    A "hunk" is a group of changed-line blocks whose context lines touch or
    overlap. To visualize, think of each block as a cluster of changed lines,
    and a hunk as a collection of these clusters that are close enough to be
    shown together.

    For example, suppose lines 1, 2, 6, and 100 each have an edit, with Context = 2
    in a file of at least 102 lines. Using human-readable, one-based line numbers:

        Hunk 1 (lines 1-8):
            Lines 1-2   Changed block A (adjacent edits grouped together)
            Lines 3-5   Unchanged context
            Line  6     Changed block B
            Lines 7-8   Unchanged context

        ... unchanged lines 9-97 omitted from the diff ...

        Hunk 2 (lines 98-102):
            Lines 98-99   Unchanged context
            Line  100     Changed block C
            Lines 101-102 Unchanged context

    Blocks A and B share a hunk because their two-line context ranges overlap.
    Block C is too far away, so it starts a separate hunk. This is an illustrative
    layout, not literal formatter output; this function groups the blocks and
    leaves rendering to Format-AstDiff. Returned block line indexes are zero-based.
#>
function Get-AstDiffHunk {
    [OutputType([List[object]])]
    param (
        [Parameter(Mandatory)]
        [AstTextEdit[]] $SortedEdits,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [int[]] $SelectedIndexes,

        [Parameter(Mandatory)]
        [object[]] $LineRecords,

        [Parameter(Mandatory)]
        [int] $Context
    )

    $LastLineIndex = $LineRecords.Count - 1
    $LineTerminatorPattern = '\r\n|\n|\r'

    # Group selected edits into blocks of contiguous changed lines.
    $Blocks = [List[hashtable]]::new()
    foreach ($Index in $SelectedIndexes) {
        $Edit = $SortedEdits[$Index]
        $StartLine = Get-AstLineIndexFromOffset -LineRecords $LineRecords -Offset $Edit.StartOffset
        $EndLine = if ($Edit.EndOffset -gt $Edit.StartOffset) {
            Get-AstLineIndexFromOffset -LineRecords $LineRecords -Offset ($Edit.EndOffset - 1)
        } else {
            $StartLine
        }

        # Removing a terminator joins the next line, so include it to show the joined result.
        $ConsumesTerminator = $Edit.EndOffset -gt $LineRecords[$EndLine].ContentEnd
        $ReplacementEndsLine = $Edit.ReplacementText -match "(?:$LineTerminatorPattern)\z"
        $RemovesWholeLines = $Edit.StartOffset -eq $LineRecords[$StartLine].Start -and
            [string]::IsNullOrEmpty($Edit.ReplacementText)

        if ($ConsumesTerminator -and
            -not $ReplacementEndsLine -and
            -not $RemovesWholeLines -and
            $EndLine -lt $LastLineIndex
        ) {
            $EndLine++
        }

        $PreviousBlock = if ($Blocks.Count -gt 0) { $Blocks[$Blocks.Count - 1] }
        if ($PreviousBlock -and $StartLine -le $PreviousBlock.EndLine + 1) {
            $PreviousBlock.EndLine = [Math]::Max($PreviousBlock.EndLine, $EndLine)
            $PreviousBlock.Items.Add(@{ Index = $Index; Edit = $Edit })
        } else {
            $Items = [List[hashtable]]::new()
            $Items.Add(@{ Index = $Index; Edit = $Edit })
            $Blocks.Add(@{ StartLine = $StartLine; EndLine = $EndLine; Items = $Items })
        }
    }

    # Combine blocks into hunks when their context lines would touch or overlap.
    $Hunks = [List[object]]::new()
    foreach ($Block in $Blocks) {
        $PreviousHunk = $null
        if ($Hunks.Count -gt 0) {
            $PreviousHunk = $Hunks[$Hunks.Count - 1]
        }

        $ContextWouldConnectBlocks = $false
        if ($PreviousHunk) {
            $PreviousBlock = $PreviousHunk[$PreviousHunk.Count - 1]
            $UnchangedLineCount = $Block.StartLine - $PreviousBlock.EndLine - 1
            $ContextWouldConnectBlocks = $UnchangedLineCount -le 2 * $Context
        }

        if ($ContextWouldConnectBlocks) {
            $PreviousHunk.Add($Block)
        } else {
            $Hunk = [List[hashtable]]::new()
            $Hunk.Add($Block)
            $Hunks.Add($Hunk)
        }
    }

    return , $Hunks
}
