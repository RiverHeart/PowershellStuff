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
        [object] $State,

        [System.Windows.Controls.Panel] $Panel
    )

    if ($State.SelectedElement -eq $Target) {
        return
    }

    if ($State.SelectedElement) {
        Clear-WpfDesignerSelection -Canvas $Canvas -State $State
    }

    # Highlight is a separate overlay rather than a mutation of the target's own
    # BorderBrush/BorderThickness, since not every control type defines those DPs
    # (e.g. StackPanel is a bare Panel with no Border properties of its own).
    $Outline = New-WpfDesignerSelectionOutline -Canvas $Canvas -Target $Target
    $Target | Add-Member -NotePropertyName '_WPFDesignerSelectionOutline' -NotePropertyValue $Outline -Force

    $Handle = New-WpfDesignerResizeHandle -Canvas $Canvas -Target $Target
    $Target | Add-Member -NotePropertyName '_WPFDesignerResizeHandle' -NotePropertyValue $Handle -Force

    $State.SelectedElement = $Target

    if ($Panel) {
        Update-WpfDesignerPropertyPanel -Panel $Panel -State $State
    }
}
