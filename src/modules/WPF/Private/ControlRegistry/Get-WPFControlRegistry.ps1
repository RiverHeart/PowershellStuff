function Get-WPFControlRegistry {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if (-not $Script:WPFControlRegistry) {
        Write-Debug "Initializing WPF Control Registry"
        $Script:WPFControlRegistry = [hashtable]::Synchronized(@{
            ActiveContextId = $null
            Contexts        = [hashtable]::Synchronized(@{})
        })
    }

    if (-not $Script:WPFControlRegistry.Contains('Contexts')) {
        $Script:WPFControlRegistry.Contexts = [hashtable]::Synchronized(@{})
    }

    if (-not $Script:WPFControlRegistry.Contains('ActiveContextId')) {
        $Script:WPFControlRegistry.ActiveContextId = $null
    }

    return $Script:WPFControlRegistry
}
