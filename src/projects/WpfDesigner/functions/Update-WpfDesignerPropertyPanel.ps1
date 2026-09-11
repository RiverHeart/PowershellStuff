using namespace System.Windows.Controls

<#
.SYNOPSIS
    Regenerates the property panel's editor rows for the current selection.

.DESCRIPTION
    Clears Panel's existing children and, if State.SelectedElement is set,
    rebuilds one Label + input row per Get-WpfDesignerPropertyDescriptor
    result. Called from Select-WpfDesignerElement and Clear-WpfDesignerSelection
    so the panel always reflects whatever is currently selected (or nothing).
#>
function Update-WpfDesignerPropertyPanel {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Panel] $Panel,

        [Parameter(Mandatory)]
        [object] $State
    )

    $Panel.Children.Clear()

    $Selected = $State.SelectedElement
    if (-not $Selected) {
        return
    }

    $PropertyTarget = $Selected.PSObject.Properties['_WPFDesignerPropertyTarget']
    $Target = if ($PropertyTarget -and $PropertyTarget.Value) {
        $PropertyTarget.Value
    } else {
        $Selected
    }

    foreach ($Descriptor in Get-WpfDesignerPropertyDescriptor -InputObject $Target) {
        $Editor = Get-WpfDesignerPropertyEditor -Descriptor $Descriptor -Target $Target
        Add-WPFObject -InputObject $Panel -ChildObjects $Editor.Label, $Editor.Input
    }
}
