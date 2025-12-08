<#
.SYNOPSIS
    Splits a list into X sublists

.NOTES
    If the array is large and already constructed it is
    significantly faster to pass the whole array to
    `-InputObject` instead of piping it because we need to
    know the size of the array to calculate the sublists
    and this requires reconstructing the array before
    work can be done.

.EXAMPLE
    Basic usage. Use for large arrays.

    $List = 1..200523
    $Sublists = Split-Array $List -Count 5
    $Sublists.Count  # returns 5
    $Sublists[0].Count  # returns 40105

.EXAMPLE
    Pipeline usage. Use small arrays.

    $Sublists = 1..100 | Split-Array -Count 5
    $Sublists.Count  # returns 5
    $Sublists[0].Count  # returns 20
#>
function Split-Array {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object[]] $InputObject,

        [Parameter(Mandatory)]
        [uint64] $Count
    )

    begin {
        [object[]] $Array = @()
    }

    process {
        if ($MyInvocation.ExpectingInput) {
            $Array += $InputObject
        } else {
            $Array = $InputObject
        }
    }

    end {
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
}
