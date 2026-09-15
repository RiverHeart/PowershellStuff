<#
.SYNOPSIS
    Tags an object with a PSTypeName so later code can identify it by kind
    without inspecting its .NET type.

.DESCRIPTION
    Generic counterpart to the WPF module's own Add-WPFType, minus its
    closed ValidateSet - that set exists because those specific type names
    drive real dispatch behavior inside the WPF module (Update-WPFObject,
    implicit style lookup), so it isn't a fit for arbitrary project-local
    markers. This function makes no assumptions about the type name's
    meaning or a "Custom.*" prefix; it just inserts whatever is given
    (once) into PSTypeNames.
#>
function Add-PSType {
    [CmdletBinding()]
    [OutputType([void], [object])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]] $InputObject,

        [Parameter(Mandatory)]
        [string] $TypeName,

        [switch] $PassThru
    )

    process {
        foreach ($Item in $InputObject) {
            if ($TypeName -notin $Item.PSObject.TypeNames) {
                $Item.PSObject.TypeNames.Insert(0, $TypeName)
            }

            if ($PassThru) {
                Write-Output $Item
            }
        }
    }
}
