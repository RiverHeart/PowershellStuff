<#
.SYNOPSIS
    Creates a list of variables to be used in the WPF DSL context.

.DESCRIPTION
    Creates a list of variables to be used in the WPF DSL context. This is
    necessary to ensure that DSL variables and preferences are always available
    in nested scriptblocks without relying on automatic variable scoping.
#>
function New-WPFVariableList {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[psvariable]])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        # Allow caller to add additional variables as needed
        [psvariable[]] $AdditionalVariables
    )

    $DefaultVars = @(
        [psvariable]::new('this', $InputObject),
        $PSCmdlet.SessionState.PSVariable.Get('WarningPreference'),
        $PSCmdlet.SessionState.PSVariable.Get('DebugPreference'),
        $PSCmdlet.SessionState.PSVariable.Get('ErrorActionPreference'),
        $PSCmdlet.SessionState.PSVariable.Get('VerbosePreference')
    )
    $PSVars = [System.Collections.Generic.List[psvariable]]::new()
    foreach($DefaultVar in $DefaultVars) {
        if ($null -ne $DefaultVar) {
            $PSVars.Add($DefaultVar)
        }
    }

    # Propagate factory context so nested DSL keywords (Border, ContentPresenter,
    # etc.) produce FrameworkElementFactory nodes instead of live instances.
    if ($InputObject -is [System.Windows.FrameworkElementFactory] -or
        $InputObject -is [System.Windows.Controls.ControlTemplate]
    ) {
        $PSVars.Add([psvariable]::new('WPFFactoryContext', $true))
    }

    if ($AdditionalVariables) {
        $PSVars.AddRange($AdditionalVariables)
    }
    return $PSVars
}
