using namespace System.Windows.Controls

<#
.SYNOPSIS
    Marks an element as design-time-only overlay chrome.

.DESCRIPTION
    Uses a PSTypeName marker (same pattern as Add-WpfDesignerContainerMarker)
    so tree-walking code can skip the resize handle Thumb and selection
    outline Border - sibling elements added to the Canvas alongside real
    design content - without guessing based on type or incidental properties
    like IsHitTestVisible.
#>
function Add-WpfDesignerOverlayMarker {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Windows.FrameworkElement] $InputObject
    )

    process {
        if ('Custom.WpfDesigner.Overlay' -notin $InputObject.PSObject.TypeNames) {
            $InputObject.PSObject.TypeNames.Insert(0, 'Custom.WpfDesigner.Overlay')
        }
    }
}
