# Source - https://stackoverflow.com/a/78023372
# Posted by RiverHeart, modified by community. See post 'Timeline' for change history
# Retrieved 2025-12-08, License - CC BY-SA 4.0

<#
.SYNOPSIS
    Converts tabs to spaces.

.DESCRIPTION
    Converts tabs to spaces. Takes into account
    the length of the string when calculating the
    tab stop so the number of spaces will vary
    depending on the string given.

    Additional tabs will be added when a string
    exceeds the configured tab stop.

.NOTES
    Inspired by the Linux utility "expand"

.EXAMPLE
    Expand an array of strings

    ("one", "two", "three") -join "`t" | Expand-Tab

.EXAMPLE
    Expand an array of strings using a different delimiter
    and longer tab stop.

    ("one", "two", "three") -join "|" | Expand-Tab 20 -Delimiter "|"

#>
function Expand-Tab {
    [CmdletBinding()]
    [Alias('expand')]
    param(
        [Parameter(ValueFromPipeline)]
        [string[]] $InputObject,

        # Position=0 because we assume pipeline usage by default
        [Parameter(Position=0)]
        [ValidateNotNull()]
        [uint32] $TabStop = 8,

        [ValidateNotNullOrEmpty()]
        [string] $Delimiter = "`t"
    )

    begin {
        $Builder = [System.Text.StringBuilder]::new()
    }

    process {
        foreach ($String in $InputObject) {
            $Segments = $String.Split($Delimiter)
            $Counter = 0
            foreach ($Segment in $Segments) {
                $StringTabLengthRatio = $Segment.Length / $TabStop

                # Accomodate strings that are empty or equal to the tabstop by
                # adding an additional 1. For others, round up so the final
                # tabstop exceeds the string size.
                $TabStopMultiplier =
                    if ($StringTabLengthRatio -eq 1 -or
                        $StringTabLengthRatio -eq 0)
                    {
                        $StringTabLengthRatio + 1
                    }
                    else {
                        [Math]::Ceiling($StringTabLengthRatio)
                    }


                $CalculatedTabStop = $TabStop * $TabStopMultiplier
                $SpacesRequired = $CalculatedTabStop - $Segment.Length
                [void] $Builder.Append($Segment)

                # Avoid adding a trailing tab on the last item.
                $Counter += 1
                if ($Counter -lt $Segments.Count) {
                    [void] $Builder.Append(" ", $SpacesRequired)
                }
            }
            $Builder.ToString()
            [void] $Builder.Clear()
        }
    }
}
