using namespace System.Windows.Controls

<#
.SYNOPSIS
    Clears the current design surface selection, if any.

.DESCRIPTION
    Removes the selection styling and resize handle from the previously
    selected control and clears the shared SelectedElement state.
#>
function Clear-WpfDesignerSelection {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [object] $State,

        [System.Windows.Controls.Panel] $Panel
    )

    $Previous = $State.SelectedElement
    if (-not $Previous) {
        return
    }

    $OutlineSizeChangedHandlerProperty = $Previous.PSObject.Properties['_WPFDesignerSelectionOutlineSizeChangedHandler']
    if ($OutlineSizeChangedHandlerProperty -and $OutlineSizeChangedHandlerProperty.Value) {
        $Previous.remove_SizeChanged($OutlineSizeChangedHandlerProperty.Value)
    }

    $OutlineProperty = $Previous.PSObject.Properties['_WPFDesignerSelectionOutline']
    if ($OutlineProperty -and $OutlineProperty.Value) {
        $Canvas.Children.Remove($OutlineProperty.Value)
    }

    $SizeChangedHandlerProperty = $Previous.PSObject.Properties['_WPFDesignerResizeHandleSizeChangedHandler']
    if ($SizeChangedHandlerProperty -and $SizeChangedHandlerProperty.Value) {
        $Previous.remove_SizeChanged($SizeChangedHandlerProperty.Value)
    }

    $HandleProperty = $Previous.PSObject.Properties['_WPFDesignerResizeHandle']
    if ($HandleProperty -and $HandleProperty.Value) {
        $Canvas.Children.Remove($HandleProperty.Value)
    }

    $State.SelectedElement = $null

    if ($Panel) {
        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State
    }
}
