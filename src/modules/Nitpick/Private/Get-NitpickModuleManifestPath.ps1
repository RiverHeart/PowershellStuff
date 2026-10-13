<#
.SYNOPSIS
    Determines the manifest path associated with a resolved module entrypoint.

.DESCRIPTION
    Returns the entrypoint path itself when it already is a .psd1 manifest.
    Otherwise looks for a sibling <Name>.psd1 file next to a script or binary
    module entrypoint. Returns $null when no manifest is available for the
    resolved source.

.PARAMETER Path
    The resolved module entrypoint path (.psd1, .psm1, or .dll).

.PARAMETER Name
    The module's identity name, used to locate a sibling manifest file.

.EXAMPLE
    Get-NitpickModuleManifestPath -Path 'C:\Modules\WPF\WPF.psm1' -Name 'WPF'
#>
function Get-NitpickModuleManifestPath {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    if ([System.IO.Path]::GetExtension($Path) -eq '.psd1') {
        return $Path
    }

    $SiblingManifest = Join-Path -Path (Split-Path -Path $Path -Parent) -ChildPath ($Name + '.psd1')
    if (Test-Path -LiteralPath $SiblingManifest) {
        return $SiblingManifest
    }

    return $null
}
