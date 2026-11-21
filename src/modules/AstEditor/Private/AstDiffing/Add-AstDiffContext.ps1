using namespace System.Text

<#
.SYNOPSIS
    Appends an inclusive, zero-based range of unchanged source lines to a builder.
#>
function Add-AstDiffContext {
    param (
        [Parameter(Mandatory)]
        [StringBuilder] $Builder,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text,

        [Parameter(Mandatory)]
        [object[]] $LineRecords,

        [Parameter(Mandatory)]
        [int] $From,

        [Parameter(Mandatory)]
        [int] $To,

        [Parameter(Mandatory)]
        [int] $GutterWidth
    )

    for ($LineIndex = $From; $LineIndex -le $To; $LineIndex++) {
        $LineRecord = $LineRecords[$LineIndex]
        $Content = $Text.Substring($LineRecord.Start, $LineRecord.End - $LineRecord.Start)
        $Content | Add-AstDiffLine `
            -Builder $Builder `
            -GutterWidth $GutterWidth `
            -LineNumber ($LineIndex + 1) `
            -Marker ' '
    }
}
