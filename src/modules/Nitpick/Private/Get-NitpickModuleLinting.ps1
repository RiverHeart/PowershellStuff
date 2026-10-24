<#
.SYNOPSIS
    Reads and validates a resolved module's declared Nitpick rule package metadata.

.DESCRIPTION
    Reads PrivateData.Linting from the resolved module's manifest, when one is
    available, without importing the module. Distinguishes an absent Linting
    declaration (triggers standalone exported-command discovery) from a present,
    possibly empty, declaration (only its own Rules/RuleModules fields contribute).
    OwnerModule, when present, identifies a supporting package's owner.

.PARAMETER Module
    A resolved Nitpick.Module descriptor, as returned by Resolve-NitpickModuleSource.

.EXAMPLE
    Get-NitpickModuleLinting -Module $ResolvedModule
#>
function Get-NitpickModuleLinting {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [psobject] $Module
    )

    $Result = [pscustomobject] @{
        PSTypeName = 'Nitpick.ModuleLinting'
        HasLinting = $false
        Rules = @()
        RuleModules = @()
        OwnerModule = $null
    }

    if (-not $Module.ManifestPath) {
        return $Result
    }

    $ManifestData = Import-PowerShellDataFile -Path $Module.ManifestPath -ErrorAction Stop
    if (-not $ManifestData.ContainsKey('PrivateData') -or $ManifestData.PrivateData -isnot [hashtable]) {
        return $Result
    }
    if (-not $ManifestData.PrivateData.ContainsKey('Linting')) {
        return $Result
    }

    $Linting = $ManifestData.PrivateData.Linting
    if ($null -eq $Linting) {
        $Linting = @{}
    }
    if ($Linting -isnot [hashtable]) {
        throw "Manifest '$($Module.ManifestPath)' declares PrivateData.Linting as a $($Linting.GetType().Name); expected a hashtable."
    }

    $Result.HasLinting = $true

    if ($Linting.ContainsKey('Rules')) {
        $Result.Rules = @($Linting.Rules | ForEach-Object { [string] $_ })
        if ($Result.Rules | Where-Object { [string]::IsNullOrWhiteSpace($_) }) {
            throw "Manifest '$($Module.ManifestPath)' declares an empty or whitespace-only PrivateData.Linting.Rules entry."
        }
    }

    if ($Linting.ContainsKey('RuleModules')) {
        $Result.RuleModules = @($Linting.RuleModules | ForEach-Object { [string] $_ })
        if ($Result.RuleModules | Where-Object { [string]::IsNullOrWhiteSpace($_) }) {
            throw "Manifest '$($Module.ManifestPath)' declares an empty or whitespace-only PrivateData.Linting.RuleModules entry."
        }
    }

    if ($Linting.ContainsKey('OwnerModule')) {
        if ($Linting.OwnerModule -isnot [string] -or
            [string]::IsNullOrWhiteSpace($Linting.OwnerModule)) {
            throw "Manifest '$($Module.ManifestPath)' declares an invalid PrivateData.Linting.OwnerModule; expected a nonempty relative path string."
        }
        $Result.OwnerModule = $Linting.OwnerModule
    }

    return $Result
}
