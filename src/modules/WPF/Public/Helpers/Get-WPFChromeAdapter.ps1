<#
.SYNOPSIS
    Returns registered Chrome adapters.

.DESCRIPTION
    Returns Chrome adapters from the module registry, regardless of whether they
    were module-provided defaults or registered at runtime.

.EXAMPLE
    Get-WPFChromeAdapter

.EXAMPLE
    Get-WPFChromeAdapter -TargetType ([System.Windows.Controls.Button])
#>
function Get-WPFChromeAdapter {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateNotNull()]
        [type] $TargetType,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $registry = Get-WPFChromeAdapterRegistry -InitializeDefaults
    $adapters = @($registry.Values)

    if ($PSBoundParameters.ContainsKey('Name')) {
        $adapters = @(
            $adapters | Where-Object {
                $_.Name -and ([string] $_.Name).Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)
            }
        )
    }

    if ($PSBoundParameters.ContainsKey('TargetType')) {
        $exactMatches = @(
            $adapters | Where-Object {
                $_.TargetType -is [type] -and $_.TargetType -eq $TargetType
            }
        )

        if ($exactMatches.Count -gt 0) {
            $adapters = $exactMatches
        } else {
            $adapters = @(
                $adapters | Where-Object {
                    $_.TargetType -is [type] -and $_.TargetType.IsAssignableFrom($TargetType)
                }
            )
        }
    }

    return $adapters
}
