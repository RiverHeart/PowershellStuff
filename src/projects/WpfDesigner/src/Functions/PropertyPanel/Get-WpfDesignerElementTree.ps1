using namespace System.Windows.Controls

<#
.SYNOPSIS
    Walks the design surface into a flat, depth-annotated, pre-order list of
    the real element hierarchy.

.DESCRIPTION
    Recursively walks a container's children (the Window frame and any loose
    elements directly on the Canvas, then down into nested StackPanel/Border
    contents) via Get-WpfDesignerContainerChildren, so callers - a visual
    tree pane, a future recursive exporter - get a uniform Element/Depth
    pair per node without needing to know the difference between a Panel's
    Children collection and a Border's single Child slot, or filter out
    design-time overlay chrome themselves. Returns nodes flat rather than
    nested (no Children property) - a pre-order Depth sequence is all a
    row-per-node tree pane needs, and callers that do want to recurse
    further can walk Get-WpfDesignerContainerChildren themselves. Root-level
    elements (those directly on the Canvas) are Depth 0.
#>
function Get-WpfDesignerElementTree {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Element,

        [int] $Depth = 0
    )

    $Nodes = [System.Collections.Generic.List[object]]::new()

    foreach ($Child in (Get-WpfDesignerContainerChildren -Element $Element)) {
        $Nodes.Add([PSCustomObject]@{
            Element = $Child
            Depth   = $Depth
        })
        # Force array: an empty PowerShell function return unwraps to $null, which
        # AddRange rejects outright.
        $Nodes.AddRange(@(Get-WpfDesignerElementTree -Element $Child -Depth ($Depth + 1)))
    }

    return $Nodes.ToArray()
}
