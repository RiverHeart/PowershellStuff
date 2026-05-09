function Get-WPFControlTable {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string] $ContextId,

        [object] $InputObject,

        [switch] $CreateIfMissing,

        [string] $Name,

        [switch] $Activate
    )

    $State = Get-WPFControlRegistry
    $Id = Resolve-WPFControlContextId -ContextId $ContextId -InputObject $InputObject -CreateIfMissing:$CreateIfMissing -Name $Name -Activate:$Activate
    if (-not $Id) {
        return $null
    }

    if (-not $State.Contexts.ContainsKey($Id)) {
        if (-not $CreateIfMissing) {
            return $null
        }

        [void] (New-WPFControlContext -Name $Name -ContextId $Id -Activate:$Activate)
    }

    return $State.Contexts[$Id].Objects
}
