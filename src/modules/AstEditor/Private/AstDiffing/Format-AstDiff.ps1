using namespace System
using namespace System.Text
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Renders diff hunks as one string with reason labels and numbered source lines.

.DESCRIPTION
    Consumes the nested hunk/block lists produced by Get-AstDiffHunk. Formatting
    scriptblocks share only this function's builder, source, and display settings.
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
    $Esc = if (-not $ColorIsDisabled) { [char]27 }
    $Red = if (-not $ColorIsDisabled) { "$Esc[31m" }
    $Green = if (-not $ColorIsDisabled) { "$Esc[32m" }
    $Reset = if (-not $ColorIsDisabled) { "$Esc[0m" }
    $Bold = if (-not $ColorIsDisabled) { "$Esc[1m" }

    $LastLineIndex = $LineRecords.Count - 1
    # A trailing terminator produces an empty final line that should never appear as context.
    $LastContentLineIndex = if ($LastLineIndex -gt 0 -and $LineRecords[$LastLineIndex].Start -eq $Text.Length) {
        $LastLineIndex - 1
    } else {
        $LastLineIndex
    }

    $NumberWidth = ([string] ($LastContentLineIndex + 1)).Length
    $LineTerminatorPattern = '\r\n|\n|\r'
    $SplitDisplayLines = {
        param ([string] $Value)
        if ($Value.Length -eq 0) {
            return , @()
        }
        $Trimmed = [regex]::Replace($Value, "(?:$LineTerminatorPattern)\z", '')
        return , [regex]::Split($Trimmed, $LineTerminatorPattern)
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
            $LineRecord = $LineRecords[$LineIndex]
            & $AppendLine ($LineIndex + 1) ' ' $Text.Substring($LineRecord.Start, $LineRecord.ContentEnd - $LineRecord.Start) $null
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
                $StartLineIndex = Get-AstLineIndexFromOffset -LineRecords $LineRecords -Offset $StartOffset
                '{0}:{1} ' -f ($StartLineIndex + 1), ($StartOffset - $LineRecords[$StartLineIndex].Start + 1)
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

            $SpanStart = $LineRecords[$Block.StartLine].Start
            $Original = $Text.Substring($SpanStart, $LineRecords[$Block.EndLine].End - $SpanStart)

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
