using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates the abstract Window frame on the design surface.

.DESCRIPTION
    A real System.Windows.Window can't be embedded as a visual child of
    another element, so the exported Window's bounds are represented on the
    canvas as a resizable Border acting as window chrome instead. A hidden
    Window supplies the editable Window properties, while a default Canvas
    inside the Border hosts freely positioned controls. Reuses the existing
    selection/resize-handle mechanics (Select-WpfDesignerElement) rather than
    introducing a separate resize path for the frame.
#>
function New-WpfDesignerWindowFrame {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Border])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [object] $State
    )

    # Left nameless (like the resize handle Thumb) since there's only ever one
    # and it's tracked via State.WindowFrame instead of by-name lookup.
    #
    # -AutoAttach $null overrides the ambient WPFAutoAttachContext (the
    # Canvas, visible here via this function's own caller frame) so Border
    # returns unparented - Add-WPFObject below is what actually places it.
    $WindowModel = [System.Windows.Window]::new()
    $WindowModel.Title = 'Window'
    $WindowModel.Width = 480
    $WindowModel.Height = 360

    $Frame = Border -AutoAttach $null {
        $this.Background = 'White'
        $this.BorderBrush = '#666666'
        $this.BorderThickness = 2
    }

    foreach ($PropertyName in 'Width', 'Height') {
        $Binding = [System.Windows.Data.Binding]::new($PropertyName)
        $Binding.Source = $WindowModel
        $Binding.Mode = [System.Windows.Data.BindingMode]::TwoWay
        $Binding.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
        $Frame.SetBinding([System.Windows.FrameworkElement]::"${PropertyName}Property", $Binding) | Out-Null
    }

    $ContentRoot = [System.Windows.Controls.Canvas]::new()
    $ContentRoot.Background = [System.Windows.Media.Brushes]::Transparent
    $ContentRoot.ClipToBounds = $true
    $Frame.Child = $ContentRoot

    $Frame | Add-Member -NotePropertyName '_WPFDesignerPropertyTarget' -NotePropertyValue $WindowModel
    $Frame | Add-Member -NotePropertyName '_WPFDesignerContentRoot' -NotePropertyValue $ContentRoot

    Add-WPFObject -InputObject $Canvas -ChildObjects $Frame
    CanvasPosition -Left 20 -Top 20 -InputObject $Frame
    Add-PSType -InputObject $Frame -TypeName 'Custom.WpfDesigner.Container'
    Add-PSType -InputObject $ContentRoot -TypeName 'Custom.WpfDesigner.Container'

    # GetNewClosure() detaches the handler from module scope, so
    # Select-WpfDesignerElement must be captured as a scriptblock reference
    # here rather than called by name below.
    $SelectHandler = ${function:Select-WpfDesignerElement}

    # The frame has no Draggable handler to mark the event Handled, so it must
    # do so itself to suppress the canvas-level deselect handler.
    On -Event MouseLeftButtonDown -InputObject $Frame -ScriptBlock {
        param($sender, $e)
        & $SelectHandler -Canvas $Canvas -Target $sender -State $State -Panel $State.PropertyPanel
        $e.Handled = $true
    }.GetNewClosure()

    $State.WindowFrame = $Frame
    $State.WindowModel = $WindowModel

    return $Frame
}
