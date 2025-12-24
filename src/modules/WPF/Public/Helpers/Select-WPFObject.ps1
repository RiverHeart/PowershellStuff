<#
.SYNOPSIS
    Returns a registered object by name.

.DESCRIPTION
    Returns a registered object by name.

    Objects are automatically registered at time of creation.

.EXAMPLE
    Get reference to the Window

    Reference 'Window'
#>
function Select-WPFObject {
    [CmdletBinding()]
    [OutputType([void], [object])]
    [Alias('Reference')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        [string] $Property
    )

    process {
        foreach($Item in $Name) {
            if ($Script:WPFControlTable.ContainsKey($Item)) {
                if ($Property) {
                    $Script:WPFControlTable[$Item] | Select-Object -ExpandProperty $Property
                } else {
                    $Script:WPFControlTable[$Item]
                }
            } else {
                Write-Error "No object registered with name '$Item'"
            }
        }
    }
}
