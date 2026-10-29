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

.EXAMPLE
    Show-AstDiff -Document $doc

    Displays every queued edit, grouped by the lines it changes.

.EXAMPLE
    Show-AstDiff -Document $doc -EditIndex 0,2 -Context 3

    Displays only the first and third queued edits with three lines of context.

.EXAMPLE
    Show-AstDiff -Document $doc -Label Position

    Labels each reason with the line:column where its first edit starts.
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
        -NoColor:$NoColor
}
