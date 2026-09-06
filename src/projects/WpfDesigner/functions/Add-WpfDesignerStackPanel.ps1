using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a new StackPanel on the design surface and makes it draggable.

.DESCRIPTION
    Backs the toolbar's "+ StackPanel" button. Thin StackPanel-specific
    wrapper around Add-WpfDesignerControl, which owns the shared placement/
    selection/drag/resize wiring. Given a visible Background since StackPanel
    is a bare Panel with no BorderBrush of its own to fall back on while
    empty.
#>
function Add-WpfDesignerStackPanel {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.StackPanel])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [object] $State
    )

    Add-WpfDesignerControl -Canvas $Canvas -State $State -Type 'StackPanel' -Container -Configure {
        $this.Width = 160
        $this.Height = 120
        $this.Background = '#E5E7EB'
    }
}
