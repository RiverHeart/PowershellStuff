function Get-WPFRegisteredObjectNames {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string] $ContextId,

        [object] $InputObject
    )

    $State = Get-WPFControlRegistry
    $Id = Resolve-WPFControlContextId -ContextId $ContextId -InputObject $InputObject

    if ($Id -and $State.Contexts.ContainsKey($Id)) {
        return @($State.Contexts[$Id].Objects.Keys)
    }

    return @(
        $State.Contexts.Values |
            ForEach-Object { $_.Objects.Keys } |
            Sort-Object -Unique
    )
}
