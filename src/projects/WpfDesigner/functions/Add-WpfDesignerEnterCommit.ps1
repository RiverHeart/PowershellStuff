using namespace System.Windows.Controls

<#
.SYNOPSIS
    Commits a bound TextBox's value on Enter instead of requiring focus loss.

.DESCRIPTION
    Clears focus when Enter is pressed. Text bindings default to
    UpdateSourceTrigger=LostFocus, which commits on the UIElement.LostFocus
    (logical focus) event rather than keyboard focus, so both the logical
    focus (FocusManager) and keyboard focus (Keyboard) must be cleared for
    the existing commit path (including any LostFocus handlers, such as
    numeric clamping) to fire.
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
            $scope = [System.Windows.Input.FocusManager]::GetFocusScope($sender)
            [System.Windows.Input.FocusManager]::SetFocusedElement($scope, $null)
            [System.Windows.Input.Keyboard]::ClearFocus()
            $e.Handled = $true
        }
    }
}
