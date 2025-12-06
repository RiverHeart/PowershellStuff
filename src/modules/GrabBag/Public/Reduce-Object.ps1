<#
.SYNOPSIS
    Reduces an array of items to a single element

.NOTES
    Not a lot of work went into this. It could be better.

.EXAMPLE
    Pipe array to reduce.

    1..10 | reduce { param($a, $b) $a + $b }

.EXAMPLE
    Provide initial value for accumulator.

    Reduce-Object `
        -InputObject @(1,2,3,4) `
        -InitialValue 2 `
        { param($a, $b) $a + $b }
#>
function Reduce-Object {
    [CmdletBinding()]
    [Alias("reduce")]
    [OutputType([Int])]
    param(
        # Meant to be passed in through pipeline.
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Array] $InputObject,

        # Position=0 because we assume pipeline usage by default.
        [Parameter(Mandatory,Position=0)]
        [ScriptBlock] $ScriptBlock,

        [Parameter(Position=1)]
        [Int] $InitialValue
    ) 

    begin {
        if ($InitialValue) { $Accumulator = $InitialValue }
    }

    process {
        foreach($Value in $InputObject) {
            if ($Accumulator) {
                # Execute script block given as param with values.
                $Accumulator = $ScriptBlock.InvokeReturnAsIs($Accumulator,  $Value)
            } else {
                # Contigency for no initial value given.
                $Accumulator = $Value
            }
        }
    }

    end {
        return $Accumulator
    }
}
