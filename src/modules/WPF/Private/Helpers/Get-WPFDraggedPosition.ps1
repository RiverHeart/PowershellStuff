<#
.SYNOPSIS
    Computes a new Canvas Left/Top position from a drag anchor and mouse delta.

.DESCRIPTION
    Pure helper used by Draggable so the position math can be unit tested
    without requiring a rendered visual tree or live mouse input.
    -MaxLeft/-MaxTop clamp the result to a [0, Max] range (typically the
    parent's size minus the dragged element's size) so a drag can be bounded
    to its parent. They're optional so unbounded dragging stays unaffected.
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
        [System.Windows.Point] $CurrentMouse,

        [double] $MaxLeft,

        [double] $MaxTop
    )

    $Left = $AnchorLeft + ($CurrentMouse.X - $AnchorMouse.X)
    $Top = $AnchorTop + ($CurrentMouse.Y - $AnchorMouse.Y)

    if ($PSBoundParameters.ContainsKey('MaxLeft')) {
        $Left = [Math]::Min([Math]::Max($Left, 0), $MaxLeft)
    }
    if ($PSBoundParameters.ContainsKey('MaxTop')) {
        $Top = [Math]::Min([Math]::Max($Top, 0), $MaxTop)
    }

    return [pscustomobject] @{
        Left = $Left
        Top  = $Top
    }
}
