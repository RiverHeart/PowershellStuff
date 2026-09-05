<#
.SYNOPSIS
    Moves the current DSL object to the front of its parent Panel's z-order.

.DESCRIPTION
    Sets the Panel.ZIndex attached property on the current object ($this) or
    an explicitly provided -InputObject to one greater than the highest
    ZIndex among its sibling elements, so it renders above every other child
    of the parent Panel.

    Requires the object to already be attached to a Panel (for example
    Canvas, Grid, or DockPanel).

.EXAMPLE
    Canvas 'Board' {
        Label 'Back' { CanvasPosition -Left 0 -Top 0 }
        Label 'Front' {
            CanvasPosition -Left 0 -Top 0
            BringToFront
        }
    }

.EXAMPLE
    BringToFront -InputObject $SomeControl
#>
function BringToFront {
    [CmdletBinding()]
    [Alias('-BringToFront')]
    [OutputType([void])]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        if ($MyInvocation.InvocationName.StartsWith('-')) {
            Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name 'BringToFront'
            return
        }

        $Target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if ($null -eq $Target) {
            Write-Error 'BringToFront: Could not resolve target object. Use BringToFront inside a DSL object block or pass -InputObject.'
            return
        }

        $Parent = $Target.Parent
        if ($Parent -isnot [System.Windows.Controls.Panel]) {
            Write-Error "BringToFront: '$($Target.Name)' must be attached to a Panel before calling BringToFront."
            return
        }

        # Exclude the target itself so repeated calls don't keep incrementing its own ZIndex.
        $MaxZIndex = [int]::MinValue
        foreach ($Sibling in $Parent.Children) {
            if ($Sibling -eq $Target) { continue }
            $SiblingZIndex = [System.Windows.Controls.Panel]::GetZIndex($Sibling)
            if ($SiblingZIndex -gt $MaxZIndex) {
                $MaxZIndex = $SiblingZIndex
            }
        }

        $NewZIndex = if ($MaxZIndex -eq [int]::MinValue) { 0 } else { $MaxZIndex + 1 }
        [System.Windows.Controls.Panel]::SetZIndex($Target, $NewZIndex)
    }
}
