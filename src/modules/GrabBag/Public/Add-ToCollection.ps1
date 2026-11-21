using namespace System.Collections

<#
.SYNOPSIS
    Adds items to a referenced array or writable, resizable list.

.DESCRIPTION
    Replaces a referenced zero-based, one-dimensional array with a larger array
    of the same element type, or mutates a writable, resizable IList.
    Each incoming object is added as one item, including incoming arrays.
    Upstream pipeline enumeration cannot be undone by this function.
    Null items are skipped unless AllowNull is specified. No items are returned.

    Array copies use .NET assignment rules rather than PowerShell conversion.
    An incompatible item fails without replacing the destination array. Earlier
    successfully added pipeline items remain; the operation is not transactional.
    Repeated array additions allocate and copy; prefer a list for large inputs.

.NOTES
    The intent behind this function is to provide a safe and consistent way
    of adding items to arrays and lists without having to worry about all
    the edge cases and limitations of array and list manipulation in PowerShell.

.EXAMPLE
    Basic usage

    $Array = @()
    1, 2, 3 | Add-ToCollection ([ref] $Array)
    Write-Output $Array  # Prints 1, 2, 3

.EXAMPLE
    Using the -AllowNull switch

    $Array1 = @()
    $Array2 = @()

    1, $null, 3 | Add-ToCollection -Collection ([ref] $Array1)
    1, $null, 3 | Add-ToCollection -Collection ([ref] $Array2) -AllowNull

    Write-Output "Array1 ($($Array1.Count)): $($Array1 -join ', ')"  # Array1 (2): 1, 3
    Write-Output "-------"
    Write-Output "Array2 ($($Array2.Count)): $($Array2 -join ', ')" # Array2 (3): 1, , 3
#>
function Add-ToCollection {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory,Position=0)]
        [AllowEmptyCollection()]
        [ref] $Collection,

        [switch] $AllowNull
    )

    begin {
        $IsArray = $Collection.Value -is [Array]
        $IsList = $Collection.Value -is [IList]
        if (-not $IsArray -and -not $IsList) {
            Write-Error `
                -Message 'Collection must reference an array or a writable, resizable IList.' `
                -Category InvalidArgument `
                -ErrorAction Stop
        }

        if ($IsArray) {
            if ($Collection.Value.Rank -ne 1 -or $Collection.Value.GetLowerBound(0) -ne 0) {
                Write-Error `
                    -Message 'Only zero-based, one-dimensional arrays are supported.' `
                    -Category InvalidArgument `
                    -ErrorAction Stop
            }
        } elseif ($Collection.Value.IsReadOnly -or $Collection.Value.IsFixedSize) {
            Write-Error `
                -Message 'Cannot add items to a read-only or fixed-size list.' `
                -Category InvalidOperation `
                -ErrorAction Stop
        }
    }

    process {
        if (-not $AllowNull -and $null -eq $InputObject) {
            return
        }

        try {
            if ($IsArray) {
                $Original = $Collection.Value
                $ElementType = $Original.GetType().GetElementType()
                $NewCollection = [Array]::CreateInstance($ElementType, $Original.Length + 1)

                [Array]::Copy($Original, $NewCollection, $Original.Length)
                $Item = $InputObject

                # Pipeline binding can wrap values in PSObject; .NET array copying
                # does not unwrap them when assigning to a typed element.
                if ($ElementType -ne [object] -and $null -ne $InputObject) {
                    $Item = $InputObject.PSObject.BaseObject
                }

                [Array]::Copy((,$Item), 0, $NewCollection, $Original.Length, 1)
                $Collection.Value = $NewCollection
            } else {
                [void] $Collection.Value.Add($InputObject)
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
