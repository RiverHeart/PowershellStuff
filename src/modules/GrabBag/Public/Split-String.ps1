<#
.SYNOPSIS
    Simple implementation of the unix 'cut' command in Powershell

.EXAMPLE
    Basic usage. Splits string on all whitespace resulting
    in a list of @('one', 'two', 'three', 'four').

    "one     two  three    four" | Split-String
#>
function Split-String {
    [CmdletBinding()]
    [Alias('cut')]
    [OutputType([string[]])]
    param(
        [Parameter(ValueFromPipeline)]
        [string] $InputObject,
        [string] $Delimiter = '\s+',
        [string[]] $Field
    )

    process {
        foreach($Item in $InputObject) {
            if ($Field) { ($_ -split $Delimiter)[$Field] }
            else { $_ -split $Delimiter}
        }
    }
}