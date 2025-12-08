<#
.SYNOPSIS
    Splits a list into X sublists

.EXAMPLE
    Basic usage

    $List = 1..200523
    $Sublists = Split-Array $List -Count 5
    $Sublists.Count  # returns 5
    $Sublists[0].Count  # returns 40105
#>
function Split-Array {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object[]] $Array,

        [Parameter(Mandatory)]
        [uint64] $Count
    )

    # If a list cannot be split return input as
    # sublist instead of throwing an error
    if ($Count -lt 2) {
        $Count = 1
    }

    $ListMax = [Math]::Ceiling($Array.Count / $Count)
    $Sublists = [Object[]]::new($Count)
    for(($i = 0), ($Start = 0), ($End = $ListMax); $Start -lt $Array.Count; ($i++), ($Start += $ListMax), ($End += $ListMax)) {
        $Sublists[$i] = $Array[$Start..($End - 1)]
    }

    # Add comma to prevent unrolling list
    return , $Sublists
}