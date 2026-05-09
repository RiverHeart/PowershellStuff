function Resolve-WPFControlContextId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $ContextId,

        [object] $InputObject,

        [switch] $CreateIfMissing,

        [string] $Name,

        [switch] $Activate
    )

    $State = Get-WPFControlRegistry

    if ($ContextId) {
        if ($State.Contexts.ContainsKey($ContextId)) {
            if ($Activate) {
                $State.ActiveContextId = $ContextId
            }
            return $ContextId
        }

        if ($CreateIfMissing) {
            return New-WPFControlContext -Name $Name -ContextId $ContextId -Activate:$Activate
        }

        return $null
    }

    $ObjectContextId = Get-WPFControlContextId -InputObject $InputObject
    if ($ObjectContextId) {
        if ($Activate) {
            $State.ActiveContextId = $ObjectContextId
        }
        return $ObjectContextId
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
