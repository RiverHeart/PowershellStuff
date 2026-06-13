<#
.SYNOPSIS
    Resolves the control context id used by the WPF registry helpers.

.DESCRIPTION
    This helper resolves a context id from several sources in priority order.
    It resolves from the current object context when supplied, then falls back
    to the active context, the only registered context, or creates a new
    context when requested.

.PARAMETER InputObject
    Optional current scope object used to infer a context id. If supplied, the
    object must already be associated with a WPF control context.

.PARAMETER CreateIfMissing
    Creates a new context when no existing context can be resolved.

.PARAMETER Name
    Optional context name used when a new context is created.

.PARAMETER Activate
    Marks the resolved or created context as the active context.

.NOTES
    When an explicitly supplied InputObject cannot be resolved, this helper
    writes an error and returns no output. Omit InputObject to allow fallback
    resolution, or use -ErrorAction to control error behavior.

.OUTPUTS
    System.String
#>
function Resolve-WPFControlContextId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateNotNull()]
        [object] $InputObject,

        [switch] $CreateIfMissing,

        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [switch] $Activate
    )

    $State = Get-WPFControlRegistry
    $InputObjectWasBound = $PSBoundParameters.ContainsKey('InputObject')

    if ($InputObjectWasBound) {
        $ObjectContextId = Get-WPFControlContextId -InputObject $InputObject
        if ($ObjectContextId) {
            if ($Activate) {
                $State.ActiveContextId = $ObjectContextId
            }
            return $ObjectContextId
        }

        $InputObjectType = $InputObject.GetType().FullName
        Write-Error "Input object of type '$InputObjectType' is not associated with a WPF control context."
        return $null
    }

    if ($State.ActiveContextId) {
        return $State.ActiveContextId
    }

    if ($State.Contexts.Count -eq 1) {
        return @($State.Contexts.Keys)[0]
    }

    if ($CreateIfMissing) {
        return New-WPFControlContext -Name $Name -Activate:$Activate
    }

    return $null
}
