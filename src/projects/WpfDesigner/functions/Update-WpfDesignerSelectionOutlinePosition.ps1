using namespace System.Windows.Controls

<#
.SYNOPSIS
    Repositions and resizes a selection outline to match its target's bounds.
#>
function Update-WpfDesignerSelectionOutlinePosition {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Border] $Outline,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Target,

        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas
    )

    $Position = Get-WpfDesignerCanvasRelativePosition -Canvas $Canvas -Target $Target

    CanvasPosition -Left $Position.X -Top $Position.Y -InputObject $Outline
    $Outline.Width = $Target.Width
    $Outline.Height = $Target.Height
}
