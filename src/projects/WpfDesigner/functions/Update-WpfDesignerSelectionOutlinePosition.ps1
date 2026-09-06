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
        [System.Windows.FrameworkElement] $Target
    )

    $Left = [System.Windows.Controls.Canvas]::GetLeft($Target)
    $Top = [System.Windows.Controls.Canvas]::GetTop($Target)
    if ([double]::IsNaN($Left)) { $Left = 0.0 }
    if ([double]::IsNaN($Top)) { $Top = 0.0 }

    CanvasPosition -Left $Left -Top $Top -InputObject $Outline
    $Outline.Width = $Target.Width
    $Outline.Height = $Target.Height
}
