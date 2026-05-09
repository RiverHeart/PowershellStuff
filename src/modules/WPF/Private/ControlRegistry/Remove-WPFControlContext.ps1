function Remove-WPFControlContext {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string] $ContextId,

        [object] $InputObject
    )

    $State = Get-WPFControlRegistry
    $Id = Resolve-WPFControlContextId -ContextId $ContextId -InputObject $InputObject
    if (-not $Id) {
        return
    }

    [void] $State.Contexts.Remove($Id)

    if ($State.ActiveContextId -eq $Id) {
        if ($State.Contexts.Count -gt 0) {
            $State.ActiveContextId = @($State.Contexts.Keys)[0]
        } else {
            $State.ActiveContextId = $null
        }
    }
}
