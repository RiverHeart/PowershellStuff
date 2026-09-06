using namespace System.Windows.Controls

<#
.SYNOPSIS
    Tests whether an element was marked as a valid drop target by
    Add-WpfDesignerContainerMarker.
#>
function Test-WpfDesignerContainer {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject
    )

    return $InputObject.PSObject.TypeNames -contains 'Custom.WpfDesigner.Container'
}
