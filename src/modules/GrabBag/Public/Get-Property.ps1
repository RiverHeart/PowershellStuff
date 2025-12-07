<#
.SYNOPSIS
    Helper utility to quickly get property values not exposed
    by Get-Member.

.EXAMPLE
    Basic usage

    $MyInvocation | Get-Property
#>
function Get-Property {
    [Alias('gprop')]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object[]] $InputObject,

        [string[]] $Property
    )

    process {
        foreach($Item in $InputObject) {
            $Result = @{}
            $Item.PSObject.Properties |
                Where-Object {
                    -not $Property -or $_.Name -in $Property
                } |
                ForEach-Object {
                    $Result[$_.Name] = $_.Value
                }
            $Result
        }
    }
}