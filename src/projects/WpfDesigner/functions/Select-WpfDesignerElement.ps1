using namespace System.Windows.Controls

<#
.SYNOPSIS
    Selects a control on the design surface and shows a resize handle for it.

.DESCRIPTION
    Backs click-to-select on the design surface. Deselects any previously
    selected control (clearing its selection styling and resize handle)
    before marking the new target as selected.
#>
function Select-WpfDesignerElement {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Target,

        [Parameter(Mandatory)]
        [object] $State
    )

    if ($State.SelectedElement -eq $Target) {
        return
    }

    if ($State.SelectedElement) {
        Clear-WpfDesignerSelection -Canvas $Canvas -State $State
    }

    # Border (used by the Window frame) defines its own BorderBrush/BorderThickness
    # dependency properties rather than sharing Control's, so the correct pair must be
    # read here and stashed for Clear-WpfDesignerSelection to restore on deselect.
    $BorderBrushProperty = if ($Target -is [System.Windows.Controls.Border]) { [System.Windows.Controls.Border]::BorderBrushProperty } else { [System.Windows.Controls.Control]::BorderBrushProperty }
    $BorderThicknessProperty = if ($Target -is [System.Windows.Controls.Border]) { [System.Windows.Controls.Border]::BorderThicknessProperty } else { [System.Windows.Controls.Control]::BorderThicknessProperty }

    $Target | Add-Member -NotePropertyName '_WPFDesignerPreviousBorderBrush' -NotePropertyValue $Target.ReadLocalValue($BorderBrushProperty) -Force
    $Target | Add-Member -NotePropertyName '_WPFDesignerPreviousBorderThickness' -NotePropertyValue $Target.ReadLocalValue($BorderThicknessProperty) -Force

    $Target.BorderBrush = '#F59E0B'
    $Target.BorderThickness = 2

    $Handle = New-WpfDesignerResizeHandle -Canvas $Canvas -Target $Target
    $Target | Add-Member -NotePropertyName '_WPFDesignerResizeHandle' -NotePropertyValue $Handle -Force

    $State.SelectedElement = $Target
}
