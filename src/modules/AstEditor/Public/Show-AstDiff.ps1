using namespace System
using namespace System.Text
using namespace System.Collections.Generic

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

    $ColorIsDisabled = $NoColor -or $env:NO_COLOR
    $Esc = if (-not $ColorIsDisabled) { [char]27 }
    $Red = if (-not $ColorIsDisabled) { "$Esc[31m" }
    $Green = if (-not $ColorIsDisabled) { "$Esc[32m" }
    $Reset = if (-not $ColorIsDisabled) { "$Esc[0m" }
    $Bold = if (-not $ColorIsDisabled) { "$Esc[1m" }

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
    $Lines = Get-AstTextLine -Text $Text
    $LineStarts = [int[]] @($Lines.Start)
    $LastLineIndex = $Lines.Count - 1

    # A trailing terminator produces an empty final line that should never appear as context.
    $LastContentLineIndex = if ($LastLineIndex -gt 0 -and $Lines[$LastLineIndex].Start -eq $Text.Length) {
        $LastLineIndex - 1
    } else {
        $LastLineIndex
    }

    $NumberWidth = ([string] ($LastContentLineIndex + 1)).Length
    $LineTerminatorPattern = '\r\n|\n|\r'

    $GetLineIndex = {
        param ([int] $Offset)
        $Found = [Array]::BinarySearch($LineStarts, $Offset)
        if ($Found -ge 0) { $Found } else { (-bnot $Found) - 1 }
    }

    $SplitDisplayLines = {
        param ([string] $Value)
        if ($Value.Length -eq 0) {
            return , @()
        }
        $Trimmed = [regex]::Replace($Value, "(?:$LineTerminatorPattern)\z", '')
        return , [regex]::Split($Trimmed, $LineTerminatorPattern)
    }

    # Group selected edits into blocks of contiguous changed lines.
    $Blocks = [List[hashtable]]::new()
    foreach ($Index in $SelectedIndexes) {
        $Edit = $SortedEdits[$Index]
        $StartLine = & $GetLineIndex $Edit.StartOffset
        $EndLine = if ($Edit.EndOffset -gt $Edit.StartOffset) {
            & $GetLineIndex ($Edit.EndOffset - 1)
        } else {
            $StartLine
        }

        # Removing a terminator joins the next line, so include it to show the joined result.
        $ConsumesTerminator = $Edit.EndOffset -gt $Lines[$EndLine].ContentEnd
        $ReplacementEndsLine = $Edit.ReplacementText -match "(?:$LineTerminatorPattern)\z"
        $RemovesWholeLines = $Edit.StartOffset -eq $Lines[$StartLine].Start -and
            [string]::IsNullOrEmpty($Edit.ReplacementText)

        if ($ConsumesTerminator -and
            -not $ReplacementEndsLine -and
            -not $RemovesWholeLines -and
            $EndLine -lt $LastLineIndex
        ) {
            $EndLine++
        }

        $Previous = if ($Blocks.Count -gt 0) { $Blocks[$Blocks.Count - 1] }
        if ($Previous -and $StartLine -le $Previous.EndLine + 1) {
            $Previous.EndLine = [Math]::Max($Previous.EndLine, $EndLine)
            $Previous.Items.Add(@{ Index = $Index; Edit = $Edit })
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

        if ($PreviousHunk -and
            $Block.StartLine - $PreviousHunk[$PreviousHunk.Count - 1].EndLine - 1 -le 2 * $Context
        ) {
            $PreviousHunk.Add($Block)
        } else {
            $Hunk = [List[hashtable]]::new()
            $Hunk.Add($Block)
            $Hunks.Add($Hunk)
        }
    }

    $Builder = [StringBuilder]::new()
    $AppendLine = {
        param ([object] $LineNumber, [string] $Marker, [string] $Content, [string] $Color)
        $Gutter = if ($null -eq $LineNumber) { ' ' * $NumberWidth } else { ([string] $LineNumber).PadLeft($NumberWidth) }
        $Prefix = if ($Color) { $Color } else { '' }
        $Suffix = if ($Color) { $Reset } else { '' }
        [void] $Builder.AppendLine("$Prefix  $Gutter $Marker $Content$Suffix")
    }

    $AppendContextLines = {
        param ([int] $From, [int] $To)
        for ($LineIndex = $From; $LineIndex -le $To; $LineIndex++) {
            $Line = $Lines[$LineIndex]
            & $AppendLine ($LineIndex + 1) ' ' $Text.Substring($Line.Start, $Line.ContentEnd - $Line.Start) $null
        }
    }

    foreach ($Hunk in $Hunks) {
        if ($Builder.Length -gt 0) {
            [void] $Builder.AppendLine('')
        }

        $ReasonGroups = [Dictionary[string, List[int]]]::new(
            [StringComparer]::Ordinal
        )
        $ReasonOrder = [List[string]]::new()
        foreach ($Block in $Hunk) {
            foreach ($Item in $Block.Items) {
                $Reason = [string] $Item.Edit.Reason
                if (-not $ReasonGroups.ContainsKey($Reason)) {
                    $ReasonGroups[$Reason] = [List[int]]::new()
                    $ReasonOrder.Add($Reason)
                }
                $ReasonGroups[$Reason].Add($Item.Index)
            }
        }

        foreach ($Reason in $ReasonOrder) {
            $ReasonLabel = if ($Label -eq 'Position') {
                # Edits are sorted by offset, so the first index marks where the reason starts.
                $StartOffset = $SortedEdits[$ReasonGroups[$Reason][0]].StartOffset
                $StartLineIndex = & $GetLineIndex $StartOffset
                '{0}:{1} ' -f ($StartLineIndex + 1), ($StartOffset - $Lines[$StartLineIndex].Start + 1)
            } else {
                '[{0}]' -f ($ReasonGroups[$Reason] -join ', ')
            }
            [void] $Builder.AppendLine("${Bold}$ReasonLabel $Reason${Reset}")
        }

        $FirstLine = $Hunk[0].StartLine
        & $AppendContextLines ([Math]::Max(0, $FirstLine - $Context)) ($FirstLine - 1)

        $PreviousEndLine = $null
        foreach ($Block in $Hunk) {
            if ($null -ne $PreviousEndLine) {
                & $AppendContextLines ($PreviousEndLine + 1) ($Block.StartLine - 1)
            }

            $SpanStart = $Lines[$Block.StartLine].Start
            $Original = $Text.Substring($SpanStart, $Lines[$Block.EndLine].End - $SpanStart)

            # Apply edits from last to first so earlier relative offsets remain valid.
            $Candidate = $Original
            for ($ItemIndex = $Block.Items.Count - 1; $ItemIndex -ge 0; $ItemIndex--) {
                $Edit = $Block.Items[$ItemIndex].Edit
                $RelativeStart = $Edit.StartOffset - $SpanStart
                $Candidate = $Candidate.Remove($RelativeStart, $Edit.EndOffset - $Edit.StartOffset)
                $Candidate = $Candidate.Insert($RelativeStart, [string] $Edit.ReplacementText)
            }

            $LineNumber = $Block.StartLine + 1
            foreach ($Line in (& $SplitDisplayLines $Original)) {
                & $AppendLine $LineNumber '-' $Line $Red
                $LineNumber++
            }

            foreach ($Line in (& $SplitDisplayLines $Candidate)) {
                & $AppendLine $null '+' $Line $Green
            }

            $PreviousEndLine = $Block.EndLine
        }

        $TrailingEnd = [Math]::Min($PreviousEndLine + $Context, $LastContentLineIndex)
        & $AppendContextLines ($PreviousEndLine + 1) $TrailingEnd
    }

    return $Builder.ToString().TrimEnd("`r", "`n")
}
