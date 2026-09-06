using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a selection outline overlay for a selected element.

.DESCRIPTION
    Some element types (e.g. StackPanel, or any bare Panel) don't define
    their own BorderBrush/BorderThickness dependency properties, so selection
    highlight can't be applied by mutating the target directly. Draws a
    separate non-hit-testable Border on the Canvas instead, positioned/sized
    to match the target's bounds - the same "overlay sibling" approach
    already used for the resize handle Thumb - so selection works uniformly
    regardless of what DPs the target itself exposes.
#>
function New-WpfDesignerSelectionOutline {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Border])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Target
    )

    # Border() auto-attaches to the ambient WPFAutoAttachContext when set, so
    # clear it first to guarantee the outline stays unparented until we
    # explicitly place it below.
    $WPFAutoAttachContext = $null
    $Outline = Border {
        $this.BorderBrush = '#F59E0B'
        $this.BorderThickness = 2
        $this.IsHitTestVisible = $false
    }

    Add-WPFObject -InputObject $Canvas -ChildObjects $Outline
    Add-WpfDesignerOverlayMarker -InputObject $Outline
    BringToFront -InputObject $Outline
    Update-WpfDesignerSelectionOutlinePosition -Outline $Outline -Target $Target -Canvas $Canvas

    # GetNewClosure() detaches the handler from module scope, so
    # Update-WpfDesignerSelectionOutlinePosition must be captured as a
    # scriptblock reference here rather than called by name below.
    $UpdatePosition = ${function:Update-WpfDesignerSelectionOutlinePosition}

    # SizeChanged catches Width/Height changes from any source (e.g. a resize
    # handle drag or the property panel). Stashed on Target so
    # Clear-WpfDesignerSelection can unsubscribe it when the outline goes away.
    $SizeChangedHandler = {
        param($sender, $e)
        & $UpdatePosition -Outline $Outline -Target $sender -Canvas $Canvas
    }.GetNewClosure()
    $Target.add_SizeChanged($SizeChangedHandler)
    $Target | Add-Member -NotePropertyName '_WPFDesignerSelectionOutlineSizeChangedHandler' -NotePropertyValue $SizeChangedHandler -Force

    return $Outline
}
