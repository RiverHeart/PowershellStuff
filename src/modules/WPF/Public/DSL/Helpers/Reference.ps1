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
function Reference {
    [CmdletBinding()]
    [Alias('Get-WPFRegisteredObject')]
    [OutputType([void], [object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({ Complete-WPFRegisteredObject @args })]
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
