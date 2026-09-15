<#
.SYNOPSIS
    Gets a WPF application module by name.

.DESCRIPTION
    Searches for a module with the specified name that has the "WPFApplication" tag.
    Returns the first matching module found.

.EXAMPLE
    Get all WPF application modules.

    Get-WPFApplication

.EXAMPLE
    Gets a specific WPF application module by name.

    Get-WPFApplication -Name MyApp
#>
function Get-WPFApplication {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $GetParams = @{
        ListAvailable = $true
    }
    if ($Name) { $GetParams.Name = $Name }
    Get-Module @GetParams | Where-Object { $_.Tags -contains "WPFApplication" }
}
