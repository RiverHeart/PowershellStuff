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
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [object] $InputObject,

        [ValidateSet('Style', 'HeaderStyle', 'ElementStyle')]
        [string] $TargetType = 'Style'
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

        $style = $script:WPFStyleTable[$Name]

        # Special handling for DataGridTextColumn
        $isDataGridTextColumn = $target.GetType().FullName -eq 'System.Windows.Controls.DataGridTextColumn'
        if ($isDataGridTextColumn -and $TargetType -in @('HeaderStyle','ElementStyle')) {
            if ($TargetType -eq 'HeaderStyle') {
                $target.HeaderStyle = $style
            } elseif ($TargetType -eq 'ElementStyle') {
                $target.ElementStyle = $style
            }
            return
        }

        # Default: assign to Style property
        if (-not $target.PSObject.Properties['Style']) {
            Write-Error "UseStyle: Target type '$($target.GetType().FullName)' does not expose a Style property."
            return
        }
        $target.Style = $style
    }
}
