using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a new Label on the design surface and makes it draggable.

.DESCRIPTION
    Backs the toolbar's "+ Label" button. Thin Label-specific wrapper around
    Add-WpfDesignerControl, which owns the shared placement/selection/drag/
    resize wiring.
#>
function Add-WpfDesignerLabel {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Label])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas,

        [Parameter(Mandatory)]
        [object] $State,

        [System.Windows.Controls.Panel] $Panel
    )

    Add-WpfDesignerControl -Canvas $Canvas -State $State -Type 'Label' -Panel $Panel -Configure {
        $this.Content = 'Label'
        $this.Width = 100
        $this.Height = 26
    }
}
