<#
.SYNOPSIS
    Creates a storyboard and assigns it to the current BeginStoryboard action.

.DESCRIPTION
    Creates a System.Windows.Media.Animation.Storyboard, executes the optional
    scriptblock with `$this` bound to that storyboard, and then either:

    - assigns it to the current BeginStoryboard when used in that context
    - returns it for manual assignment in other contexts

.EXAMPLE
    BeginStoryboard 'HoverStoryboard' {
        Storyboard {
            DoubleAnimation -Target 'GlassCube' -Property '(UIElement.Opacity)' -To 1 -Duration '0:0:0.2'
        }
    }
#>
function Storyboard {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Media.Animation.Storyboard])]
    param(
        [Parameter(Position = 0)]
        [scriptblock] $ScriptBlock,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $storyboard = [System.Windows.Media.Animation.Storyboard]::new()

        if ($ScriptBlock) {
            $PSVars = New-WPFVariableList -InputObject $storyboard
            $null = $ScriptBlock.InvokeWithContext($null, $PSVars, @())
        }

        $context = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if ($context -is [System.Windows.Media.Animation.BeginStoryboard]) {
            $context.Storyboard = $storyboard
            return
        }

        return ,$storyboard
    }
}
