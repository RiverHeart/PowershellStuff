<#
.SYNOPSIS
    Tests whether an object was tagged with a given PSTypeName by
    Add-PSType.
#>
function Test-PSType {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string[]] $TypeName
    )

    foreach ($Entry in $TypeName) {
        if ($InputObject.PSObject.TypeNames -contains $Entry) {
            return $true
        }
    }
    return $false
}
