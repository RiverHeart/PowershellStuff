using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a bottom-right resize handle for a selected control.

.DESCRIPTION
    Adds a small square Thumb to the canvas, pinned to the target's
    bottom-right corner. Dragging the handle adjusts the target's Width and
    Height (clamped to a 20px minimum, and to whatever fits within the
    Canvas's actual bounds once it's been laid out) and keeps the handle
    pinned as the target's size changes, from a drag or any other source
    (e.g. the property panel).
#>
function New-WpfDesignerResizeHandle {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Primitives.Thumb])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Target
    )

    # Thumb() auto-attaches to $this when set, so clear it first to guarantee
    # the handle stays unparented until we explicitly place it below.
    $this = $null
    $Handle = Thumb {
        $this.Width = 8
        $this.Height = 8
        $this.Background = 'White'
        $this.BorderBrush = '#2563EB'
        $this.BorderThickness = 1
        $this.Cursor = 'SizeNWSE'
    }

    Add-WPFObject -InputObject $Canvas -ChildObjects $Handle
    BringToFront -InputObject $Handle
    Update-WpfDesignerResizeHandlePosition -Handle $Handle -Target $Target

    # GetNewClosure() detaches the handler from module scope, so
    # Update-WpfDesignerResizeHandlePosition must be captured as a scriptblock
    # reference here rather than called by name below.
    $UpdatePosition = ${function:Update-WpfDesignerResizeHandlePosition}

    # Thumb.DragDelta gives incremental change since the last event, so no
    # anchor/mouse-capture bookkeeping is needed here.
    On -Event DragDelta -InputObject $Handle -ScriptBlock {
        param($sender, $e)

        $Left = [System.Windows.Controls.Canvas]::GetLeft($Target)
        if ([double]::IsNaN($Left)) { $Left = 0.0 }
        $Top = [System.Windows.Controls.Canvas]::GetTop($Target)
        if ([double]::IsNaN($Top)) { $Top = 0.0 }

        # ActualWidth/Height are 0 until the Canvas has been laid out (e.g. in
        # tests without a real PresentationSource), which would otherwise
        # clamp every resize to 20px. Treat that as "no bound yet" instead.
        $MaxWidth = if ($Canvas.ActualWidth -gt 0) { [System.Math]::Max(20, $Canvas.ActualWidth - $Left) } else { [double]::PositiveInfinity }
        $MaxHeight = if ($Canvas.ActualHeight -gt 0) { [System.Math]::Max(20, $Canvas.ActualHeight - $Top) } else { [double]::PositiveInfinity }

        $Target.Width = [System.Math]::Min($MaxWidth, [System.Math]::Max(20, $Target.Width + $e.HorizontalChange))
        $Target.Height = [System.Math]::Min($MaxHeight, [System.Math]::Max(20, $Target.Height + $e.VerticalChange))
        & $UpdatePosition -Handle $sender -Target $Target
    }.GetNewClosure()

    # SizeChanged catches Width/Height changes from any source (e.g. the
    # property panel), not just handle drags. Stashed on Target so
    # Clear-WpfDesignerSelection can unsubscribe it when the handle goes away.
    $SizeChangedHandler = {
        param($sender, $e)
        & $UpdatePosition -Handle $Handle -Target $sender
    }.GetNewClosure()
    $Target.add_SizeChanged($SizeChangedHandler)
    $Target | Add-Member -NotePropertyName '_WPFDesignerResizeHandleSizeChangedHandler' -NotePropertyValue $SizeChangedHandler -Force

    return $Handle
}

