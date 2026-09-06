using namespace System.Windows.Controls

<#
.SYNOPSIS
    Tests whether an element was marked as overlay chrome by
    Add-WpfDesignerOverlayMarker.
#>
function Test-WpfDesignerOverlay {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject
    )

    return $InputObject.PSObject.TypeNames -contains 'Custom.WpfDesigner.Overlay'
}
