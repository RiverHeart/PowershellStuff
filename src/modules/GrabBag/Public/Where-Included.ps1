<#
.SYNOPSIS
    Filters input objects based on inclusion and exclusion criteria.

.DESCRIPTION
    Filters input objects based on inclusion and exclusion criteria.

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

        $IsIncluded = if ($Include) { $Target -in $Include } else { $True }
        $IsExcluded = if ($Exclude) { $Target -in $Exclude } else { $False }
        if ($IsIncluded -and -not $IsExcluded) {
            Write-Output $InputObject
        }
    }
}
