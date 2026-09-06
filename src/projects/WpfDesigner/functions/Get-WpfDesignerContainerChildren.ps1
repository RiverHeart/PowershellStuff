using namespace System.Windows.Controls

<#
.SYNOPSIS
    Returns the real (non-overlay) child elements of a container.

.DESCRIPTION
    Uses LogicalTreeHelper.GetChildren rather than a hardcoded per-type
    if/else (Panel.Children vs. Border.Child vs. ...), so a future
    ContentControl-derived container type is picked up for free instead of
    needing a revisit here. Design-time-only overlay chrome (the resize
    handle Thumb, selection outline Border) is filtered out so callers
    never see it.
#>
function Get-WpfDesignerContainerChildren {
    [CmdletBinding()]
    [OutputType([System.Windows.FrameworkElement[]])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Element
    )

    $Candidates = [System.Windows.LogicalTreeHelper]::GetChildren($Element) |
        Where-Object { $_ -is [System.Windows.FrameworkElement] }

    return @($Candidates | Where-Object { -not (Test-WpfDesignerOverlay -InputObject $_) })
}
