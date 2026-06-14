<#
.SYNOPSIS
    Sets DockPanel docking on the current DSL object.

.DESCRIPTION
    Applies the DockPanel.Dock attached property to the current object ($this)
    or to an explicitly provided -InputObject.

    This is helper syntax for:
    [System.Windows.Controls.DockPanel]::SetDock(<object>, <dock>)

.EXAMPLE
    StatusBarItem 'StatusZoomItem' {
        Dock Right
    }

.EXAMPLE
    Dock Top -InputObject $SomeControl
#>
function Dock {
    [CmdletBinding()]
    [Alias('-Dock')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [System.Windows.Controls.Dock] $Side,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        if ($MyInvocation.InvocationName.StartsWith('-')) {
            Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name "Dock $Side"
            return
        }

        $Target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if ($null -eq $Target) {
            Write-Error 'Dock: Could not resolve target object. Use Dock inside a DSL object block or pass -InputObject.'
            return
        }

        [System.Windows.Controls.DockPanel]::SetDock($Target, $Side)
    }
}
