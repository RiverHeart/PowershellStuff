function Set-WPFControlActiveContext {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    $State = Get-WPFControlRegistry
    if ($State.Contexts.ContainsKey($ContextId)) {
        $State.ActiveContextId = $ContextId
    }
}
