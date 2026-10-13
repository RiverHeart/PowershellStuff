using namespace System.IO
using namespace System.Management.Automation

<#
.SYNOPSIS
    Resolves a bare module name to a pinned rule package source.

.DESCRIPTION
    Reuses a single matching already-loaded instance and rejects ambiguous loaded
    instances rather than choosing one arbitrarily. Otherwise selects the highest
    available version and rejects equally eligible distinct sources tied at that
    version; an explicit path resolves that ambiguity. A module name must match
    exactly, so wildcard patterns are rejected.

.PARAMETER Value
    The bare module name to resolve.

.EXAMPLE
    Resolve-NitpickModuleNameSource -Value 'WPF'
#>
function Resolve-NitpickModuleNameSource {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Value
    )

    if ($Value.IndexOfAny([char[]] @('*', '?', '[', ']')) -ge 0) {
        throw [InvalidDataException]::new("Module name '$Value' must match exactly; wildcard patterns are not supported.")
    }

    $LoadedMatches = Get-Module -All | Where-Object { $_.Name -eq $Value }
    if ($LoadedMatches.Count -gt 1) {
        throw [InvalidDataException]::new("Module name '$Value' is ambiguous; multiple loaded instances were found. Specify an explicit path to disambiguate.")
    }

    if ($LoadedMatches.Count -eq 1) {
        $Instance = $LoadedMatches | Select-Object -First 1
        $ModuleParams = @{
            Name = $Instance.Name
            Version = $Instance.Version
            Path = $Instance.Path
            ManifestPath = (Get-NitpickModuleManifestPath -Path $Instance.Path -Name $Instance.Name)
            LoadedInstance = $Instance
        }
        New-NitpickModule @ModuleParams
        return
    }

    $AvailableMatches = @(Get-Module -ListAvailable -Name $Value | Where-Object { $_.Name -eq $Value })
    if ($AvailableMatches.Count -eq 0) {
        throw [ItemNotFoundException]::new("Module '$Value' was not found.")
    }

    $HighestVersion = ($AvailableMatches | Sort-Object -Property Version -Descending | Select-Object -First 1).Version
    $TopMatches = $AvailableMatches | Where-Object { $_.Version -eq $HighestVersion }
    $DistinctPaths = $TopMatches.Path | Select-Object -Unique

    if ($DistinctPaths.Count -gt 1) {
        throw [InvalidDataException]::new("Module name '$Value' is ambiguous; multiple distinct sources at version '$HighestVersion' were found. Specify an explicit path to disambiguate.")
    }

    $Selected = $TopMatches | Select-Object -First 1
    $ModuleParams = @{
        Name = $Selected.Name
        Version = $Selected.Version
        Path = $Selected.Path
        ManifestPath = (Get-NitpickModuleManifestPath -Path $Selected.Path -Name $Selected.Name)
    }
    New-NitpickModule @ModuleParams
}
