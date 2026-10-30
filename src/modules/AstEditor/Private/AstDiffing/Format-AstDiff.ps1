using namespace System
using namespace System.Text
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Renders diff hunks as one string with reason labels and numbered source lines.

.DESCRIPTION
    Consumes the nested hunk/block lists produced by Get-AstDiffHunk. Renders
    reason labels, leading context, edited blocks, and trailing context in order.
    Private helpers handle line splitting and appending with explicit inputs.
#>
function Format-AstDiff {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text,

        [Parameter(Mandatory)]
        [object[]] $LineRecords,

        [Parameter(Mandatory)]
        [AstTextEdit[]] $SortedEdits,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [List[object]] $Hunks,

        [Parameter(Mandatory)]
        [int] $Context,

        [Parameter(Mandatory)]
        [ValidateSet('Index', 'Position')]
        [string] $Label,

        [switch] $NoColor
    )

    $ColorIsDisabled = $NoColor -or $env:NO_COLOR
    if (-not $ColorIsDisabled) {
        $Esc = [char]27
        $Reset = "$Esc[0m"
        $Bold = "$Esc[1m"
    } else {
        $Reset = ''
        $Bold = ''
    }

    $LastLineIndex = $LineRecords.Count - 1
    # A trailing terminator produces an empty final line that should never appear as context.
    $LastContentLineIndex = if (
        $LastLineIndex -gt 0 -and
        $LineRecords[$LastLineIndex].Start -eq $Text.Length
    ) {
        $LastLineIndex - 1
    } else {
        $LastLineIndex
    }

    $NumberWidth = ($LastContentLineIndex + 1).ToString().Length
    $Builder = [StringBuilder]::new()

    foreach ($Hunk in $Hunks) {
        if ($Builder.Length -gt 0) {
            [void] $Builder.AppendLine('')
        }

        # Group edits by reason for display purposes.
        $ReasonGroups = [Dictionary[string, List[int]]]::new([StringComparer]::Ordinal)
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

        # Display reason groups in the order they were encountered.
        foreach ($Reason in $ReasonOrder) {
            $ReasonLabel = if ($Label -eq 'Position') {
                # Edits are sorted by offset, so the first index marks where the reason starts.
                $StartOffset = $SortedEdits[$ReasonGroups[$Reason][0]].StartOffset
                $StartLineIndex = Get-AstLineIndexFromOffset -LineRecords $LineRecords -Offset $StartOffset
                '{0}:{1} ' -f ($StartLineIndex + 1), ($StartOffset - $LineRecords[$StartLineIndex].Start + 1)
            } else {
                '[{0}]' -f ($ReasonGroups[$Reason] -join ', ')
            }

            [void] $Builder.AppendLine("${Bold}$ReasonLabel $Reason${Reset}")
        }

        $FirstLine = $Hunk[0].StartLine
        Add-AstDiffContext `
            -Builder $Builder `
            -Text $Text `
            -LineRecords $LineRecords `
            -From ([Math]::Max(0, $FirstLine - $Context)) `
            -To ($FirstLine - 1) `
            -GutterWidth $NumberWidth

        $PreviousEndLine = $null
        foreach ($Block in $Hunk) {
            if ($null -ne $PreviousEndLine) {
                Add-AstDiffContext `
                    -Builder $Builder `
                    -Text $Text `
                    -LineRecords $LineRecords `
                    -From ($PreviousEndLine + 1) `
                    -To ($Block.StartLine - 1) `
                    -GutterWidth $NumberWidth
            }

            $BlockStartOffset = $LineRecords[$Block.StartLine].Start
            $OriginalBlockText = $Text.Substring(
                $BlockStartOffset,
                $LineRecords[$Block.EndLine].End - $BlockStartOffset
            )

            # Apply edits from last to first so earlier relative offsets remain valid.
            $EditedBlockText = $OriginalBlockText
            for ($ItemIndex = $Block.Items.Count - 1; $ItemIndex -ge 0; $ItemIndex--) {
                $Edit = $Block.Items[$ItemIndex].Edit
                $EditOffsetInBlock = $Edit.StartOffset - $BlockStartOffset
                $EditedBlockText = $EditedBlockText.Remove($EditOffsetInBlock, $Edit.EndOffset - $Edit.StartOffset)
                $EditedBlockText = $EditedBlockText.Insert($EditOffsetInBlock, [string] $Edit.ReplacementText)
            }

            $LineNumber = $Block.StartLine + 1

            $OriginalBlockText | Add-AstDiffLine `
                -Builder $Builder `
                -GutterWidth $NumberWidth `
                -LineNumber $LineNumber `
                -Marker '-' `
                -Color 'Red' `
                -NoColor:$ColorIsDisabled

            # Replacement lines have no original source line number.
            $EditedBlockText | Add-AstDiffLine `
                -Builder $Builder `
                -GutterWidth $NumberWidth `
                -Marker '+' `
                -Color 'Green' `
                -NoColor:$ColorIsDisabled

            $PreviousEndLine = $Block.EndLine
        }

        $TrailingEnd = [Math]::Min($PreviousEndLine + $Context, $LastContentLineIndex)
        Add-AstDiffContext `
            -Builder $Builder `
            -Text $Text `
            -LineRecords $LineRecords `
            -From ($PreviousEndLine + 1) `
            -To $TrailingEnd `
            -GutterWidth $NumberWidth
    }

    return $Builder.ToString().TrimEnd("`r", "`n")
}
