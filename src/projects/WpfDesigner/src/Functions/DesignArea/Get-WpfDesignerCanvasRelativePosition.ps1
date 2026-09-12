using namespace System.Windows.Controls

<#
.SYNOPSIS
    Resolves a target element's position relative to the root design Canvas.

.DESCRIPTION
    Elements placed directly on the Canvas are positioned via the Canvas.Left/
    Top attached properties. Elements nested inside a container (e.g. a
    StackPanel) don't have meaningful values for those, since a non-Canvas
    parent ignores them entirely - their position is resolved via
    TransformToVisual against the Canvas instead. That fallback requires a
    completed layout pass to be accurate, same as ActualWidth/ActualHeight
    elsewhere in this project.
#>
function Get-WpfDesignerCanvasRelativePosition {
    [CmdletBinding()]
    [OutputType([System.Windows.Point])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Target
    )

    if ($null -eq $Target.Parent -or $Target.Parent -eq $Canvas) {
        $Left = [System.Windows.Controls.Canvas]::GetLeft($Target)
        $Top = [System.Windows.Controls.Canvas]::GetTop($Target)
        if ([double]::IsNaN($Left)) { $Left = 0.0 }
        if ([double]::IsNaN($Top)) { $Top = 0.0 }
        return [System.Windows.Point]::new($Left, $Top)
    }

    return $Target.TransformToVisual($Canvas).Transform([System.Windows.Point]::new(0, 0))
}
