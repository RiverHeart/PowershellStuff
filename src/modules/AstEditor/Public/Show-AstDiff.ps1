<#
.SYNOPSIS
    Shows a text diff for all or selected queued edits in an AstDocument.

.DESCRIPTION
    Formats the queued edits as numbered diff blocks based on the document's
    sorted edit list. When EditIndex is provided, only those zero-based edit
    positions are shown. The output is intended for quick inspection rather than
    patch application.

.EXAMPLE
    Show-AstDiff -Document $doc

    Displays every queued edit in sorted order.

.EXAMPLE
    Show-AstDiff -Document $doc -EditIndex 0,2

    Displays only the first and third queued edits.
#>
function Show-AstDiff {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter()]
        [int[]] $EditIndex
    )

    $SortedEdits = $Document.Edits | Sort-Object -Property StartOffset, EndOffset
    if ($SortedEdits.Count -eq 0) {
        return 'No queued edits.'
    }

    if ($PSBoundParameters.ContainsKey('EditIndex')) {
        $SelectedIndexes = $EditIndex | Sort-Object -Unique
    } else {
        $SelectedIndexes = 0..($SortedEdits.Count - 1)
    }

    $Builder = [System.Text.StringBuilder]::new()
    foreach ($Index in $SelectedIndexes) {
        if (($Index -lt 0) -or ($Index -ge $SortedEdits.Count)) {
            throw "Edit index $Index is out of range. Valid range is 0..$($SortedEdits.Count - 1)."
        }

        $Edit = $SortedEdits[$Index]
        $OriginalText = if ($Edit.EndOffset -gt $Edit.StartOffset) {
            $Document.OriginalText.Substring($Edit.StartOffset, $Edit.EndOffset - $Edit.StartOffset)
        } else {
            '<insert>'
        }

        if ($Builder.Length -gt 0) {
            [void] $Builder.AppendLine('')
        }

        [void] $Builder.AppendLine("[$Index] $($Edit.Reason)")
        [void] $Builder.AppendLine("  Offsets: $($Edit.StartOffset)..$($Edit.EndOffset)")
        [void] $Builder.AppendLine('  --- original ---')
        [void] $Builder.AppendLine($OriginalText)
        [void] $Builder.AppendLine('  +++ replacement +++')
        [void] $Builder.AppendLine($Edit.ReplacementText)
    }

    return $Builder.ToString().TrimEnd()
}
