function Clear-WPFControlRegistry {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Write-Debug "Clearing WPF Control Registry"
    $State = Get-WPFControlRegistry

    # Dispose all IDisposable objects before clearing the registry
    foreach ($ContextId in $State.Contexts.Keys) {
        $Context = $State.Contexts[$ContextId]
        foreach ($ObjectName in $Context.Objects.Keys) {
            $Object = $Context.Objects[$ObjectName]
            if ($Object -is [System.IDisposable]) {
                try {
                    Write-Debug "Disposing object '$ObjectName' from context '$ContextId'"
                    $Object.Dispose()
                } catch {
                    Write-Warning "Failed to dispose object '$ObjectName' from context '$ContextId': $_"
                }
            }
        }
    }

    $State.Contexts = @{}
    $State.ActiveContextId = $null
}
