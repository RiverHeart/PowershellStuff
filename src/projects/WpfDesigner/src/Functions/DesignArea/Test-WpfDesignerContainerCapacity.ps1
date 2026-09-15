using namespace System.Windows.Controls

<#
.SYNOPSIS
    Tests whether a container-marked element still has room for another child.

.DESCRIPTION
    Border (used by the Window frame) only has a single Child slot, unlike a
    Panel-derived container like StackPanel whose Children collection is
    unbounded, so a Border can only accept a new child while its Child slot
    is empty.
#>
function Test-WpfDesignerContainerCapacity {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Container
    )

    if ($Container -is [System.Windows.Controls.Border]) {
        return -not $Container.Child
    }

    return $true
}
