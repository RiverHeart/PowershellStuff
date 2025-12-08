<#
.SYNOPSIS
    Formats an array of strings or objects that can
    cast to string in columns

.NOTES
    Format-Wide is not configurable enough and
    takes up too much space.

.EXAMPLE

    $Example = @(
        "one", "two", "three"
        "four", "five", "six"
        "seven", "eight", "nine"
    )

    $Example | Format-Column  -Columns 3 -Spacing 20
#>
function Format-Column {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]] $InputObject,

        [Parameter(Position=0)]
        [ValidateNotNull()]
        [uint32] $Columns = 3,

        [Parameter(Position=1)]
        [ValidateNotNull()]
        [uint32] $Spacing = 8,

        [ValidateNotNullOrEmpty()]
        [string] $Property
    )

    begin {
        $LineBuffer = [System.Text.StringBuilder]::new()
        $ColumnCounter = 0
    }

    process {
        foreach ($Item in $InputObject) {
            [string] $Segment = if ($Property) { $Item.$Property } else { $Item }

            # Flush buffer
            if ($ColumnCounter -eq $Columns) {
                $LineBuffer.ToString() | Expand-Tab $Spacing
                [void] $LineBuffer.Clear()
                $ColumnCounter = 0
            }

            if($ColumnCounter -eq 3) {
                [void] $LineBuffer.Append($Segment)
            } else {
                [void] $LineBuffer.Append($Segment).Append("`t")
            }
            $ColumnCounter += 1
        }
    }

    end {
        # Flush anything left over
        if ($LineBuffer.Length -gt 0) {
            $LineBuffer.ToString() | Expand-Tab $Spacing
            [void] $LineBuffer.Clear()
        }
    }
}
