using namespace System.Windows.Controls

<#
.SYNOPSIS
    Commits a bound TextBox's value on Enter instead of requiring focus loss.

.DESCRIPTION
    Clears keyboard focus when Enter is pressed. Text bindings default to
    UpdateSourceTrigger=LostFocus, so this triggers the existing commit path
    (including any LostFocus handlers, such as numeric clamping) without
    moving focus to another control.
#>
function Add-WpfDesignerEnterCommit {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.TextBox] $InputObject
    )

    On -Event KeyDown -InputObject $InputObject -ScriptBlock {
        param($sender, $e)

        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            [System.Windows.Input.Keyboard]::ClearFocus()
            $e.Handled = $true
        }
    }
}
