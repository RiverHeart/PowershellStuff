<#
.SYNOPSIS
    Gets the interfaces implemented by the input object.

.EXAMPLE
    Get the interfaces implemented by the string object.

    "string" | Get-Interface
#>
function Get-Interface {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $InputObject.GetType().ImplementedInterfaces
    }
}
