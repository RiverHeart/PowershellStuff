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
        [Parameter(Position = 0)]
        [object] $InputObject,

        # Allow caller to add additional variables as needed
        [psvariable[]] $AdditionalVariables,

        # Caller's session state, used to capture preference variables from the
        # calling scope rather than the module scope.
        [System.Management.Automation.SessionState] $CallerSessionState
    )

    $PrefSource = if ($CallerSessionState) { $CallerSessionState.PSVariable } else { $PSCmdlet.SessionState.PSVariable }
    $DefaultVars = @(
        if ($null -ne $InputObject) { [psvariable]::new('this', $InputObject) }
        $PrefSource.Get('WarningPreference'),
        $PrefSource.Get('DebugPreference'),
        $PrefSource.Get('ErrorActionPreference'),
        $PrefSource.Get('VerbosePreference')
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

    # Grid layout is declarative in this DSL: children declared inside Row/Column
    # still need to be returned so Grid can assign row/column coordinates.
    if ($InputObject -is [System.Windows.Controls.Grid]) {
        $PSVars.Add([psvariable]::new('WPFCollectChildren', $true))
    }

    if ($AdditionalVariables) {
        $PSVars.AddRange($AdditionalVariables)
    }
    return $PSVars
}
