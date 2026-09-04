using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a new Label on the design surface and makes it draggable.

.DESCRIPTION
    Backs the toolbar's "+ Label" button. Places the new Label at a staggered
    position so repeated clicks don't stack labels exactly on top of each other.
#>
function Add-WpfDesignerLabel {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Label])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas
    )

    # Label() auto-attaches to $this when set, so clear it first to guarantee
    # the new Label stays unparented until we place it on the canvas below.
    $this = $null
    $NewLabel = Label "Label_$([guid]::NewGuid().ToString('N'))" {
        $this.Content = 'Label'
    }

    Add-WPFObject -InputObject $Canvas -ChildObjects $NewLabel
    $StaggerOffset = 20 + (($Canvas.Children.Count - 1) % 8) * 24
    CanvasPosition -Left $StaggerOffset -Top $StaggerOffset -InputObject $NewLabel
    Draggable -InputObject $NewLabel -BringToFrontOnDrag

    return $NewLabel
}
