using namespace System.Management.Automation

<#
.SYNOPSIS
    Constructs a resolved Nitpick module descriptor.

.DESCRIPTION
    The single construction point for a resolved PowerShell module source, so
    its shape (name, version, resolved path, manifest location, loaded instance)
    changes in exactly one place. IsLoaded is derived from LoadedInstance rather
    than passed separately, so the two can never disagree.

.PARAMETER Name
    The resolved module's identity name.

.PARAMETER Version
    The resolved module's identity version, when known.

.PARAMETER Path
    The resolved entrypoint path (.psd1, .psm1, or .dll).

.PARAMETER ManifestPath
    The manifest path backing the resolved source, when one is available.

.PARAMETER LoadedInstance
    The already-loaded module instance being reused, when one exactly matches.

.EXAMPLE
    New-NitpickModule -Name WPF -Version '1.0.0' -Path 'C:\Modules\WPF\WPF.psd1' `
        -ManifestPath 'C:\Modules\WPF\WPF.psd1'
#>
function New-NitpickModule {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [version] $Version,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [string] $ManifestPath,

        [PSModuleInfo] $LoadedInstance
    )

    [pscustomobject] @{
        PSTypeName = 'Nitpick.Module'
        Name = $Name
        Version = $Version
        Path = $Path
        ManifestPath = $ManifestPath
        LoadedInstance = $LoadedInstance
        IsLoaded = [bool] $LoadedInstance
    }
}
