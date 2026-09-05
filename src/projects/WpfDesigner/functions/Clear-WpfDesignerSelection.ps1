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
        [object] $State
    )

    $Previous = $State.SelectedElement
    if (-not $Previous) {
        return
    }

    $Previous.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)
    $Previous.ClearValue([System.Windows.Controls.Control]::BorderThicknessProperty)

    $HandleProperty = $Previous.PSObject.Properties['_WPFDesignerResizeHandle']
    if ($HandleProperty -and $HandleProperty.Value) {
        $Canvas.Children.Remove($HandleProperty.Value)
    }

    $State.SelectedElement = $null
}
