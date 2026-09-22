<#
.SYNOPSIS
    Filters input objects based on inclusion and exclusion criteria.

.DESCRIPTION
    Filters input objects based on inclusion and exclusion criteria.

    In a way, it's a bit of syntax sugar for `Where-Object` with `-in` and `-notin` parameters
    but comes with some key benefits.

    With `Where-Object`, you're forced to use a scriptblock because it cannot convert an
    `Object[]` to `String` required by `-Property` preventing use of `-In` and `-NotIn`.
    Additionally, it gracefully handles `$null` values in both the inclusion and exclusion
    lists.

    ```
    param(
        $Include = 1, 'two'
        $Exclude
    )

    1, 'one', 2, 'two' | Where-Object {
        ($null -ne $Include -and $_ -in $Include) -and
        ($null -eq $Exclude -or $_ -notin $Exclude)
    }
    ```

    Contrast with `Where-Included`,

    ```
    param(
        $Include = 1, 'two'
        $Exclude
    )

    1, 'one', 2, 'two' | Where-Included -Include $Include -Exclude $Exclude
    ```

.NOTES
    `Get-Included` is the "official" name for the real name `Where-Included`
    since Import-Module is whiny about allowed verbs.

.EXAMPLE
    Filter basic values

    1, 'one', 2, 'two' | Where-Included -Include 1, 'two'

.EXAMPLE
    Include processes named 'powershell' by filtering on the 'ProcessName' property

    Get-Process | Where-Included -Property 'ProcessName' -Include 'powershell'

.EXAMPLE
    Exclude processes named 'notepad' by filtering on the 'ProcessName' property

    Get-Process | Where-Included -Property 'ProcessName' -Exclude 'notepad'
#>
function Get-Included {
    [CmdletBinding()]
    [Alias('Where-Included')]
    [OutputType([object])]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $InputObject,

        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [string[]] $Include,
        [string[]] $Exclude
    )

    process {
        $Target = if ($Property) { $InputObject.$Property } else { $InputObject }

        $IsIncluded = if ($null -ne $Include) { $Target -in $Include } else { $True }
        $IsExcluded = if ($null -ne $Exclude) { $Target -in $Exclude } else { $False }
        if ($IsIncluded -and -not $IsExcluded) {
            Write-Output $InputObject
        }
    }
}
