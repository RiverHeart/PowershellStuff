<#
.SYNOPSIS
    Sets Canvas positioning attached properties on the current DSL object.

.DESCRIPTION
    Applies the Canvas.Left, Canvas.Top, Canvas.Right, Canvas.Bottom, and
    Panel.ZIndex attached properties to the current object ($this) or to an
    explicitly provided -InputObject.

    Only the properties supplied by the caller are set; unspecified properties
    are left untouched.

    -Left and -Right are mutually exclusive, as are -Top and -Bottom, since WPF
    only honors one side of each axis when both are set on a Canvas child.

    This is helper syntax for:
    [System.Windows.Controls.Canvas]::SetLeft(<object>, <value>)
    [System.Windows.Controls.Canvas]::SetTop(<object>, <value>)
    [System.Windows.Controls.Canvas]::SetRight(<object>, <value>)
    [System.Windows.Controls.Canvas]::SetBottom(<object>, <value>)
    [System.Windows.Controls.Panel]::SetZIndex(<object>, <value>)

.EXAMPLE
    Canvas 'Board' {
        Label 'Piece' {
            CanvasPosition -Left 10 -Top 20
        }
    }

.EXAMPLE
    CanvasPosition -Left 10 -Top 20 -InputObject $SomeControl
#>
function CanvasPosition {
    [CmdletBinding()]
    [Alias('-CanvasPosition')]
    [OutputType([void])]
    param(
        [double] $Left,

        [double] $Top,

        [double] $Right,

        [double] $Bottom,

        [int] $ZIndex,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        if ($MyInvocation.InvocationName.StartsWith('-')) {
            Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name 'CanvasPosition'
            return
        }

        if ($PSBoundParameters.ContainsKey('Left') -and $PSBoundParameters.ContainsKey('Right')) {
            Write-Error 'CanvasPosition: Specify either -Left or -Right, not both.'
            return
        }
        if ($PSBoundParameters.ContainsKey('Top') -and $PSBoundParameters.ContainsKey('Bottom')) {
            Write-Error 'CanvasPosition: Specify either -Top or -Bottom, not both.'
            return
        }

        $Target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if ($null -eq $Target) {
            Write-Error 'CanvasPosition: Could not resolve target object. Use CanvasPosition inside a DSL object block or pass -InputObject.'
            return
        }

        if ($PSBoundParameters.ContainsKey('Left')) {
            [System.Windows.Controls.Canvas]::SetLeft($Target, $Left)
        }
        if ($PSBoundParameters.ContainsKey('Top')) {
            [System.Windows.Controls.Canvas]::SetTop($Target, $Top)
        }
        if ($PSBoundParameters.ContainsKey('Right')) {
            [System.Windows.Controls.Canvas]::SetRight($Target, $Right)
        }
        if ($PSBoundParameters.ContainsKey('Bottom')) {
            [System.Windows.Controls.Canvas]::SetBottom($Target, $Bottom)
        }
        if ($PSBoundParameters.ContainsKey('ZIndex')) {
            [System.Windows.Controls.Panel]::SetZIndex($Target, $ZIndex)
        }
    }
}
