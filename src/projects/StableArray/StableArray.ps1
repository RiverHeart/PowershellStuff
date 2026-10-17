using namespace System
using namespace System.Collections
using namespace System.Collections.Generic

# Considering an ArrayList that overrides GetEnumerator() to return a single object but keep
# indexer syntax. Also considered adding a toggle to return the entire list the next time
# GetEnumerator() is consumed but no way to know if the next caller is assigning or if
# the value is being piped to another cmdlet. Then again, we could add a `-NoEnumerate`
# switch to cmdlets that return arrays that.
<#
NoEnumerate() {
        $this.SuppressNext = $true
        return $this
    }
    [System.Collections.IEnumerator] GetEnumerator() {
        if ($this.SuppressNext) {
            $this.SuppressNext = $false
            return (, $this).GetEnumerator()
        }
        return ([System.Collections.ArrayList] $this).ToArray().GetEnumerator()
    }
}

# Matroska style array preservation function.
# Still enumerates on intermediate assignments, not just returns.
function Write-PreservedArray {
    param(
        $InputObject
    )
    return  (, (, $InputObject).GetEnumerator()).GetEnumerator()
}
#>

# https://devblogs.microsoft.com/powershell/understanding-powershells-type-conversion-magic/

# StableArray is a custom array class designed to handle PowerShell array footguns more reliably.
# For instance, it can help avoid issues with single-element arrays being treated differently than multi-element arrays.
# It wraps a list without implementing IEnumerable, so PowerShell treats it as a single value.
# Use GetEnumerator() to iterate the contents or ToArray() to create an array snapshot.
#
# WARNING: Nulls cannot be cast to complex types. Anything that might be null
# should be passed through a StableArray method to ensure proper handling.
class StableArray {
    hidden [List[object]] $Items = [List[object]]::new()
    [bool] $IgnoreNulls = $false

    [IEnumerator] GetEnumerator() {
        return $this.Items.GetEnumerator()
    }

    StableArray() {}

    StableArray([object] $items) {
        if ($null -ne $items) {
            if ($items -is [Array]) {
                foreach ($item in $items) {
                    $this.Items.Add($item)
                }
            } else {
                $this.Items.Add($items)
            }
        }
    }

    [void] Add([object] $item) {
        if ($this.IgnoreNulls -and $null -eq $item) {
            return
        }
        $this.Items.Add($item)
    }

    [void] Clear() {
        $this.Items.Clear()
    }

    [object] Item([int] $index) {
        return $this.Items[$index]
    }

    [object[]] ToArray() {
        return $this.Items.ToArray()
    }
}

<#
.SYNOPSIS
    Collects input objects into a non-enumerating list wrapper.
.DESCRIPTION
    Each supplied input object is added once. An array passed directly is stored as
    one item; pipe its elements to collect them individually. No input creates an
    empty wrapper. Explicit nulls are retained unless IgnoreNulls is true.
#>
function New-StableArray {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $InputObject,

        [bool] $IgnoreNulls = $false
    )

    begin {
        $sa = [StableArray]::new()
        $sa.IgnoreNulls = $IgnoreNulls
    }

    process {
        if ($PSBoundParameters.ContainsKey('InputObject')) {
            $sa.Add($InputObject)
        }
    }

    end {
        return $sa
    }
}

Update-TypeData `
    -TypeName StableArray `
    -MemberType ScriptProperty `
    -MemberName Count `
    -Value { $this.Items.Count } `
    -Force

$StableArray = [StableArray]::new()
$StableArray.GetType()

$StableArray = 'test' -as [StableArray]  # Explicit cast from scalar works as expected
$StableArray.GetType()  # Still a StableArray
$StableArray.Count  # > 1
$StableArray[0]  # > 'StableArray'

function AttemptToUnrollStableArray {
    param(
        [StableArray] $Array
    )
    return $Array
}

$Unrolled = AttemptToUnrollStableArray -Array $StableArray
$Unrolled.GetType()  # Should still be StableArray despite containing a single item

$NoNullsArray = 1, 2, 3, $null, 5 | New-StableArray -IgnoreNulls $true
$NoNullsArray.GetType()  # Should be StableArray
$NoNullsArray.Count  # Should be 4, as $null is ignored
