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
        [System.Windows.Controls.Border] $Handle,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Target
    )

    $Left = [System.Windows.Controls.Canvas]::GetLeft($Target)
    $Top = [System.Windows.Controls.Canvas]::GetTop($Target)
    if ([double]::IsNaN($Left)) { $Left = 0.0 }
    if ([double]::IsNaN($Top)) { $Top = 0.0 }

    CanvasPosition -Left ($Left + $Target.Width - ($Handle.Width / 2)) -Top ($Top + $Target.Height - ($Handle.Height / 2)) -InputObject $Handle
}
