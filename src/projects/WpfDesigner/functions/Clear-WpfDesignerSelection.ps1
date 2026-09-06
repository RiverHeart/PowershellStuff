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

    # Border (used by the Window frame) defines its own BorderBrush/BorderThickness
    # dependency properties rather than sharing Control's, so restore whichever local
    # value (if any) Select-WpfDesignerElement stashed instead of assuming Control's.
    $BorderBrushProperty = if ($Previous -is [System.Windows.Controls.Border]) { [System.Windows.Controls.Border]::BorderBrushProperty } else { [System.Windows.Controls.Control]::BorderBrushProperty }
    $BorderThicknessProperty = if ($Previous -is [System.Windows.Controls.Border]) { [System.Windows.Controls.Border]::BorderThicknessProperty } else { [System.Windows.Controls.Control]::BorderThicknessProperty }

    $PreviousBorderBrushProperty = $Previous.PSObject.Properties['_WPFDesignerPreviousBorderBrush']
    $PreviousBorderBrush = if ($PreviousBorderBrushProperty) { $PreviousBorderBrushProperty.Value } else { [System.Windows.DependencyProperty]::UnsetValue }
    if ($PreviousBorderBrush -eq [System.Windows.DependencyProperty]::UnsetValue) {
        $Previous.ClearValue($BorderBrushProperty)
    } else {
        $Previous.SetValue($BorderBrushProperty, $PreviousBorderBrush)
    }

    $PreviousBorderThicknessProperty = $Previous.PSObject.Properties['_WPFDesignerPreviousBorderThickness']
    $PreviousBorderThickness = if ($PreviousBorderThicknessProperty) { $PreviousBorderThicknessProperty.Value } else { [System.Windows.DependencyProperty]::UnsetValue }
    if ($PreviousBorderThickness -eq [System.Windows.DependencyProperty]::UnsetValue) {
        $Previous.ClearValue($BorderThicknessProperty)
    } else {
        $Previous.SetValue($BorderThicknessProperty, $PreviousBorderThickness)
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
}
