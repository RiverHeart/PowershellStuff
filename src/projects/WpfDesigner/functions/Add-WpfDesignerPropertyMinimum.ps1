using namespace System.Windows.Controls

<#
.SYNOPSIS
    Clamps a numeric TextBox's committed value to a minimum on LostFocus.

.DESCRIPTION
    Backs the Width/Height property panel fields. Parses the TextBox's text
    when it loses focus and, if valid, writes the clamped value directly onto
    the currently selected design surface element. The panel's existing
    two-way binding then reflects the corrected value back into the TextBox.
#>
function Add-WpfDesignerPropertyMinimum {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.TextBox] $InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PropertyName,

        [Parameter(Mandatory)]
        [double] $Minimum,

        [Parameter(Mandatory)]
        [object] $State
    )

    # GetNewClosure() detaches the handler from module scope, so
    # Get-WpfDesignerClampedValue must be captured as a scriptblock reference
    # here rather than called by name below.
    $ClampValue = ${function:Limit-WPFNumber}

    On -Event LostFocus -InputObject $InputObject -ScriptBlock {
        param($sender, $e)

        $Target = $State.SelectedElement
        if (-not $Target) {
            return
        }

        $Value = 0.0
        if ([double]::TryParse($sender.Text, [ref] $Value)) {
            $Target.$PropertyName = & $ClampValue -Value $Value -Minimum $Minimum
        }
    }.GetNewClosure()
}
