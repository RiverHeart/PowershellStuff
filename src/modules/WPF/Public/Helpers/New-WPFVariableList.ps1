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

    # Collector ownership is explicit and must be declared by the owning keyword.
    $IsCollectorOwner = $InputObject -and (Test-WPFType -InputObject $InputObject -Type 'CollectorOwner')
    if ($IsCollectorOwner) {
        $PSVars.Add([psvariable]::new('WPFCollectChildren', $true))
    } else {
        # Explicitly shadow collection mode in non-owner contexts so collector
        # intent does not leak into nested control scriptblocks.
        $PSVars.Add([psvariable]::new('WPFCollectChildren', $false))
    }

    if ($AdditionalVariables) {
        $PSVars.AddRange($AdditionalVariables)
    }
    return $PSVars
}
