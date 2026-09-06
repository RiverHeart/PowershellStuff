using namespace System.Windows.Controls

<#
.SYNOPSIS
    Marks an element as a valid drop target for newly created controls.

.DESCRIPTION
    Uses a PSTypeName marker (rather than a hardcoded list of container
    types) so new container-capable control types can opt in later without
    revisiting every place that checks "is this a valid container." Scoped to
    this project rather than reusing the WPF module's own Custom.WPF.* marker
    system, which is closed to a fixed set of DSL-internal type names.
#>
function Add-WpfDesignerContainerMarker {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Windows.FrameworkElement] $InputObject
    )

    process {
        if ('Custom.WpfDesigner.Container' -notin $InputObject.PSObject.TypeNames) {
            $InputObject.PSObject.TypeNames.Insert(0, 'Custom.WpfDesigner.Container')
        }
    }
}
