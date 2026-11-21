<#
.SYNOPSIS
    Shows a text diff for all or selected queued edits in an AstDocument.

.DESCRIPTION
    Formats queued edits as line-oriented hunks. Edits touching the same or
    adjacent lines are grouped, so related edits are shown together as complete
    original ('-') and corrected ('+') lines. Each hunk lists the reasons of its
    edits, labeled as described for Label. Identical reasons within a hunk share
    one label. Removed and context lines are numbered by their position in the
    original text.

    When EditIndex is provided, only those positions in the sorted edit list are
    shown. Context adds that many unchanged lines around each hunk; hunks whose
    context would overlap are combined. The output is intended for inspection
    rather than patch application.

.PARAMETER Context
    The number of unchanged lines to show before and after each hunk. Defaults to
    zero, which shows only the lines spanning the grouped edits.

.PARAMETER Label
    How each reason is labeled. 'Index' (default) lists the zero-based edit
    indexes, such as '[0, 1]'. 'Position' shows the one-based line:column where
    the reason's first edit starts, such as '29:13', which editors can resolve
    against a preceding file path.

.PARAMETER Annotate
    Adds caret rows beneath removed and added edit spans. Spans on the
    same line share one row. Multi-line spans annotate only their first line.
    Carets describe queued edit ranges, not minimal character differences.
    Prefix tabs are preserved; widths use UTF-16 units, not terminal display cells.

.EXAMPLE
    Display every queued edit, grouped by the lines it changes.

    Show-AstDiff -Document $doc

.EXAMPLE
    Display only the first and third queued edits with three lines of context.

    Show-AstDiff -Document $doc -EditIndex 0,2 -Context 3

.EXAMPLE
    Label each reason with the line:column where its first edit starts.

    Show-AstDiff -Document $doc -Label Position

.EXAMPLE
    Add caret rows beneath removed and added edit spans without ANSI colors.

    Show-AstDiff -Document $doc -Annotate -NoColor
#>
function Show-AstDiff {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter()]
        [int[]] $EditIndex,

        [ValidateRange(0, 2147483647)]
        [int] $Context = 0,

        [ValidateSet('Index', 'Position')]
        [string] $Label = 'Index',

        [switch] $Annotate,

        [switch] $NoColor
    )

    $SortedEdits = @($Document.Edits | Sort-Object -Property StartOffset, EndOffset)
    if ($SortedEdits.Count -eq 0) {
        Write-Verbose 'No queued edits.'
        return
    }

    if ($PSBoundParameters.ContainsKey('EditIndex')) {
        $SelectedIndexes = @($EditIndex | Sort-Object -Unique)
    } else {
        $SelectedIndexes = 0..($SortedEdits.Count - 1)
    }

    foreach ($Index in $SelectedIndexes) {
        if (($Index -lt 0) -or ($Index -ge $SortedEdits.Count)) {
            throw "Edit index $Index is out of range. Valid range is 0..$($SortedEdits.Count - 1)."
        }
    }

    $Text = $Document.OriginalText
    $LineRecords = Get-AstTextLine -Text $Text
    $Hunks = Get-AstDiffHunk `
        -SortedEdits $SortedEdits `
        -SelectedIndexes $SelectedIndexes `
        -LineRecords $LineRecords `
        -Context $Context

    return Format-AstDiff `
        -Text $Text `
        -LineRecords $LineRecords `
        -SortedEdits $SortedEdits `
        -Hunks $Hunks `
        -Context $Context `
        -Label $Label `
        -Annotate:$Annotate `
        -NoColor:$NoColor
}
