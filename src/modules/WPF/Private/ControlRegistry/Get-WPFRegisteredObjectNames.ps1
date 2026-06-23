function Get-WPFRegisteredObjectNames {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string] $ContextId,

        [object] $InputObject
    )

    $State = Get-WPFControlRegistry
    if ($PSBoundParameters.ContainsKey('ContextId')) {
        if (-not (Test-WPFControlContextId -ContextId $ContextId)) {
            return @()
        }

        $Id = $ContextId
    } else {
        $ResolveContextParams = @{}

        if ($PSBoundParameters.ContainsKey('InputObject')) {
            $ResolveContextParams.InputObject = $InputObject
        }

        $Id = Resolve-WPFControlContextId @ResolveContextParams
    }

    if ($Id -and $State.Contexts.ContainsKey($Id)) {
        return @($State.Contexts[$Id].Objects.Keys)
    }

    return @(
        $State.Contexts.Values |
            ForEach-Object { $_.Objects.Keys } |
            Sort-Object -Unique
    )
}
