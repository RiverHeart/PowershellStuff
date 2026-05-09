function Get-WPFControlRegistry {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if (-not $Script:WPFControlRegistry) {
        Write-Debug "Initializing WPF Control Registry"
        $Script:WPFControlRegistry = [ordered] @{
            ActiveContextId = $null
            Contexts        = @{}
        }
    }

    if (-not $Script:WPFControlRegistry.Contains('Contexts')) {
        $Script:WPFControlRegistry.Contexts = @{}
    }

    if (-not $Script:WPFControlRegistry.Contains('ActiveContextId')) {
        $Script:WPFControlRegistry.ActiveContextId = $null
    }

    return $Script:WPFControlRegistry
}
