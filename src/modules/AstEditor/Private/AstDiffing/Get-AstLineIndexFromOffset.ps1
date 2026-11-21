<#
.SYNOPSIS
    Finds the zero-based line index containing a source offset.

.DESCRIPTION
    Binary-searches the Start offsets of ordered records from Get-AstTextLine.
    Returns the index of the last record starting at or before the offset.
    Offsets within a line terminator belong to that line. An end-of-text offset
    maps to the final record, including the empty record after a trailing terminator.

.EXAMPLE
    $LineRecords = Get-AstTextLine -Text "first`r`nsecond"
    Get-AstLineIndexFromOffset -LineRecords $LineRecords -Offset 8

    Returns 1, since offset 8 falls within the second line.

.NOTES
    Searches line records directly instead of using [Array]::BinarySearch to
    avoid creating a temporary array of Start offsets on each lookup.
#>
function Get-AstLineIndexFromOffset {
    [OutputType([int])]
    param (
        [Parameter(Mandatory)]
        [object[]] $LineRecords,

        [Parameter(Mandatory)]
        [int] $Offset
    )

    $Low = 0
    $High = $LineRecords.Count - 1
    while ($Low -le $High) {
        $Middle = $Low + (($High - $Low) -shr 1)
        $StartOffset = $LineRecords[$Middle].Start
        if ($StartOffset -eq $Offset) {
            return $Middle
        }

        if ($StartOffset -lt $Offset) {
            $Low = $Middle + 1
        } else {
            $High = $Middle - 1
        }
    }

    return $High
}
