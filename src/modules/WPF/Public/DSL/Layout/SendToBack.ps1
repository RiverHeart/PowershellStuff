<#
.SYNOPSIS
    Moves the current DSL object to the back of its parent Panel's z-order.

.DESCRIPTION
    Sets the Panel.ZIndex attached property on the current object ($this) or
    an explicitly provided -InputObject to one less than the lowest ZIndex
    among its sibling elements, so it renders behind every other child of the
    parent Panel.

    Requires the object to already be attached to a Panel (for example
    Canvas, Grid, or DockPanel).

.EXAMPLE
    Canvas 'Board' {
        Label 'Front' { CanvasPosition -Left 0 -Top 0 }
        Label 'Back' {
            CanvasPosition -Left 0 -Top 0
            SendToBack
        }
    }

.EXAMPLE
    SendToBack -InputObject $SomeControl
#>
function SendToBack {
    [CmdletBinding()]
    [Alias('-SendToBack')]
    [OutputType([void])]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        if ($MyInvocation.InvocationName.StartsWith('-')) {
            Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name 'SendToBack'
            return
        }

        $Target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if ($null -eq $Target) {
            Write-Error 'SendToBack: Could not resolve target object. Use SendToBack inside a DSL object block or pass -InputObject.'
            return
        }

        $Parent = $Target.Parent
        if ($Parent -isnot [System.Windows.Controls.Panel]) {
            Write-Error "SendToBack: '$($Target.Name)' must be attached to a Panel before calling SendToBack."
            return
        }

        # Exclude the target itself so repeated calls don't keep decrementing its own ZIndex.
        $MinZIndex = [int]::MaxValue
        foreach ($Sibling in $Parent.Children) {
            if ($Sibling -eq $Target) { continue }
            $SiblingZIndex = [System.Windows.Controls.Panel]::GetZIndex($Sibling)
            if ($SiblingZIndex -lt $MinZIndex) {
                $MinZIndex = $SiblingZIndex
            }
        }

        $NewZIndex = if ($MinZIndex -eq [int]::MaxValue) { 0 } else { $MinZIndex - 1 }
        [System.Windows.Controls.Panel]::SetZIndex($Target, $NewZIndex)
    }
}
