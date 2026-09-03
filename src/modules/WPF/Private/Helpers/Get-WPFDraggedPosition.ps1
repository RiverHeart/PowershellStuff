<#
.SYNOPSIS
    Computes a new Canvas Left/Top position from a drag anchor and mouse delta.

.DESCRIPTION
    Pure helper used by Draggable so the position math can be unit tested
    without requiring a rendered visual tree or live mouse input.
#>
function Get-WPFDraggedPosition {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [double] $AnchorLeft,

        [Parameter(Mandatory)]
        [double] $AnchorTop,

        [Parameter(Mandatory)]
        [System.Windows.Point] $AnchorMouse,

        [Parameter(Mandatory)]
        [System.Windows.Point] $CurrentMouse
    )

    return [pscustomobject] @{
        Left = $AnchorLeft + ($CurrentMouse.X - $AnchorMouse.X)
        Top  = $AnchorTop + ($CurrentMouse.Y - $AnchorMouse.Y)
    }
}
