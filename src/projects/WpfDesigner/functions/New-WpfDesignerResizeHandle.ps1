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

    # Thumb() auto-attaches to the ambient WPFAutoAttachContext when set, so
    # override it here to guarantee the handle stays unparented until we
    # explicitly place it below.
    $Handle = Thumb -AutoAttach:$false {
        $this.Width = 8
        $this.Height = 8
        $this.Background = 'White'
        $this.BorderBrush = '#2563EB'
        $this.BorderThickness = 1
        $this.Cursor = 'SizeNWSE'
    }

    Add-WPFObject -InputObject $Canvas -ChildObjects $Handle
    Add-WpfDesignerOverlayMarker -InputObject $Handle
    BringToFront -InputObject $Handle
    Update-WpfDesignerResizeHandlePosition -Handle $Handle -Target $Target -Canvas $Canvas

    # GetNewClosure() detaches the handler from module scope, so
    # Update-WpfDesignerResizeHandlePosition must be captured as a scriptblock
    # reference here rather than called by name below.
    $UpdatePosition = ${function:Update-WpfDesignerResizeHandlePosition}
    $ClampValue = ${function:Limit-WPFNumber}

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

        $Target.Width = & $ClampValue -Value ($Target.Width + $e.HorizontalChange) -Minimum 20 -Maximum $MaxWidth
        $Target.Height = & $ClampValue -Value ($Target.Height + $e.VerticalChange) -Minimum 20 -Maximum $MaxHeight
        & $UpdatePosition -Handle $sender -Target $Target -Canvas $Canvas
    }.GetNewClosure()

    # SizeChanged catches Width/Height changes from any source (e.g. the
    # property panel), not just handle drags. Stashed on Target so
    # Clear-WpfDesignerSelection can unsubscribe it when the handle goes away.
    $SizeChangedHandler = {
        param($sender, $e)
        & $UpdatePosition -Handle $Handle -Target $sender -Canvas $Canvas
    }.GetNewClosure()
    $Target.add_SizeChanged($SizeChangedHandler)
    $Target | Add-Member -NotePropertyName '_WPFDesignerResizeHandleSizeChangedHandler' -NotePropertyValue $SizeChangedHandler -Force

    return $Handle
}

