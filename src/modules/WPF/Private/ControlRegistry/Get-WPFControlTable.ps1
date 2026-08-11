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
    if ($PSBoundParameters.ContainsKey('ContextId')) {
        if (Test-WPFControlContextId -ContextId $ContextId) {
            $Id = $ContextId
        } elseif ($CreateIfMissing) {
            $Id = New-WPFControlContext -Name $Name -ContextId $ContextId -Activate:$Activate
        } else {
            [void] (Test-WPFControlContextId -ContextId $ContextId -ErrorIfMissing)
            return $null
        }
    } else {
        $ResolveContextParams = @{
            CreateIfMissing = $CreateIfMissing
            Activate        = $Activate
        }

        if ($PSBoundParameters.ContainsKey('InputObject')) {
            $ResolveContextParams.InputObject = $InputObject
        }

        if ($PSBoundParameters.ContainsKey('Name')) {
            $ResolveContextParams.Name = $Name
        }

        $Id = Resolve-WPFControlContextId @ResolveContextParams
    }

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
