using namespace System.Windows.Controls

<#
.SYNOPSIS
    Repositions a resize handle at the target's bottom-right corner.
#>
function Update-WpfDesignerResizeHandlePosition {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Primitives.Thumb] $Handle,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Target,

        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas
    )

    $Position = Get-WpfDesignerCanvasRelativePosition -Canvas $Canvas -Target $Target

    CanvasPosition -Left ($Position.X + $Target.Width - ($Handle.Width / 2)) -Top ($Position.Y + $Target.Height - ($Handle.Height / 2)) -InputObject $Handle
}
