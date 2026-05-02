<#
.SYNOPSIS
    Applies a registered style to a control.

.DESCRIPTION
    Looks up a named style from module state and assigns it to the target
    object's Style property.

.EXAMPLE
    Button 'SaveButton' {
        UseStyle 'App.Button'
    }
#>
function UseStyle {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        if (-not $script:WPFStyleTable -or -not $script:WPFStyleTable.ContainsKey($Name)) {
            Write-Error "UseStyle: Style '$Name' is not registered."
            return
        }

        $target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not $target) {
            Write-Error "UseStyle: Unable to resolve target object for style '$Name'."
            return
        }

        if (-not $target.PSObject.Properties['Style']) {
            Write-Error "UseStyle: Target type '$($target.GetType().FullName)' does not expose a Style property."
            return
        }

        $target.Style = $script:WPFStyleTable[$Name]
    }
}
