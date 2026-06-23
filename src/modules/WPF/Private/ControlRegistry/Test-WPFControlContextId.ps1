
<#
.SYNOPSIS
    Tests if a WPF control context exists.

.DESCRIPTION
    This helper checks if a WPF control context exists in the registry by its ContextId.
    Optionally, it can throw an error if the context is missing.
#>
function Test-WPFControlContextId {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $ContextId,

        [switch] $ErrorIfMissing
    )

    $State = Get-WPFControlRegistry
    $Exists = $State.Contexts.ContainsKey($ContextId)

    if (-not $Exists -and $ErrorIfMissing) {
        Write-Error "No WPF control context exists with id '$ContextId'."
    }

    return $Exists
}
