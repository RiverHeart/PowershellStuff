<#
.SYNOPSIS
    Converts the conventional Unix table display format into an object.

.NOTES
    Since we're parsing a display format, there is no strict standard and
    thus this cmdlet cannot be expected to handle all input gracefully.

.EXAMPLE
    Basic usage

    @"
    name                     id    state    port
    ls                       345   active   3491
    "a program with space"   179            26487
    "@ | ConvertFrom-StringTable
#>
function ConvertFrom-StringTable {
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $String,

        # In case there's a buffer line between headers and column data like '----'
        [uint32[]] $SkipLines
    )

    begin {
        $LineIndex = 0
        $ColumnInfo = @()
    }

    process {
        foreach($Line in $String -Split "`n") {
            if ($LineIndex -in $SkipLines) {
                continue
            }

            $LineResult = [ordered] @{}

            # Assume first line is headers. Figure out column start/end
            # based on the start index of each header. We also assume that
            # all values are left-oriented. This would not work if column values
            # were center or right oriented.
            if ($LineIndex -eq 0) {
                $Headers =[regex]::Matches($Line,'(^|\s)\S+')
                $ColumnCount = $Headers.Count
                $NextColumn = 1

                foreach($Header in $Headers) {
                    $StartIndex = $Header.Index
                    $EndIndex = if ($NextColumn -ge $ColumnCount) { $null } else { $Headers[$NextColumn].Index - $StartIndex }
                    $ColumnInfo += @{ Name = $Header.Value.Trim(); StartIndex = $StartIndex; EndIndex = $EndIndex }
                    $NextColumn++
                }
            } else {
                foreach($Column in $ColumnInfo) {
                    # Get substring until end of line
                    if ($null -eq $Column.EndIndex) {
                        $LineResult[$Column.Name] = $Line.Substring($Column.StartIndex).Trim()
                    # Get substring from start of current column to start of next column
                    } else {
                        $LineResult[$Column.Name] = $Line.Substring(
                            $Column.StartIndex,
                            $Column.EndIndex
                        ).Trim()
                    }
                }
                Write-Output ([pscustomobject] $LineResult)
            }
            $LineIndex++
        }
    }
}
