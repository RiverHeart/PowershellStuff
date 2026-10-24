<#
.SYNOPSIS
    Resolves a literal module path to a pinned rule package source.

.DESCRIPTION
    Accepts a module manifest, script module, binary module, or module directory
    using PowerShell's standard entrypoint conventions. Rejects provider-qualified
    paths outside the FileSystem provider, unsupported file extensions, and
    directories without a matching entrypoint. A missing path is an explicit error;
    it never falls back to name-based resolution.

    Reuses an already-loaded instance only when it is loaded from this exact
    resolved path. A same-named module loaded from a different path does not
    satisfy an explicit path. Module identity, including version, is read from
    the manifest data file without executing module code.

.PARAMETER Value
    The literal module path to resolve.

.EXAMPLE
    Resolve-NitpickModulePathSource -Value '.\WPF\WPF.psd1'
#>
function Resolve-NitpickModulePathSource {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Value
    )

    try {
        [PathInfo[]] $ResolvedPathInfo = Resolve-Path -LiteralPath $Value -ErrorAction Stop
    } catch {
        throw [ItemNotFoundException]::new("Module path '$Value' was not found.")
    }

    if ($ResolvedPathInfo.Count -gt 1) {
        throw [InvalidDataException]::new("Module path '$Value' resolved to multiple filesystem locations; specify a single path.")
    }

    if ($ResolvedPathInfo[0].Provider.Name -ne 'FileSystem') {
        throw [InvalidDataException]::new("Module path '$Value' must reference the FileSystem provider.")
    }

    $Item = Get-Item -LiteralPath $ResolvedPathInfo[0].ProviderPath -ErrorAction Stop

    if ($Item.PSIsContainer) {
        $EntrypointName = $Item.Name
        # Index instead of Select-Object -First 1, which leaks a spurious
        # StopUpstreamCommandsException into a caller's -ErrorVariable on Windows
        # PowerShell 5.1 whenever -ErrorAction is also specified. Unlike .Count,
        # indexing into a genuinely $null [array]-typed variable still throws, so
        # guard the index with a Count check rather than relying on [array] alone.
        [array] $Entrypoints = '.psd1', '.psm1', '.dll' |
            ForEach-Object { Join-Path -Path $Item.FullName -ChildPath ($EntrypointName + $_) } |
            Where-Object { Test-Path -LiteralPath $_ }
        $Entrypoint = if ($Entrypoints.Count -gt 0) { $Entrypoints[0] } else { $null }

        if (-not $Entrypoint) {
            throw [InvalidDataException]::new("Module directory '$($Item.FullName)' must contain a $EntrypointName.psd1, $EntrypointName.psm1, or $EntrypointName.dll entrypoint.")
        }

        $ResolvedPath = $Entrypoint
        $ResolvedName = $EntrypointName
    } else {
        if ($Item.Extension -notin '.psd1', '.psm1', '.dll') {
            throw [InvalidDataException]::new(
                "Module path '$($Item.FullName)' must be a module directory, .psd1 manifest, .psm1 script module, or .dll binary module."
            )
        }

        $ResolvedPath = $Item.FullName
        $ResolvedName = $Item.BaseName
    }

    $ManifestPath = Get-NitpickModuleManifestPath -Path $ResolvedPath -Name $ResolvedName

    [array] $LoadedInstances = Get-Module -All | Where-Object { $_.Path -eq $ResolvedPath }
    $LoadedInstance = if ($LoadedInstances.Count -gt 0) { $LoadedInstances[0] } else { $null }

    $ResolvedVersion = $null
    if ($LoadedInstance) {
        $ResolvedVersion = $LoadedInstance.Version
    } elseif ($ManifestPath) {
        $ManifestData = Import-PowerShellDataFile -Path $ManifestPath -ErrorAction Stop
        if ($ManifestData.ModuleVersion) {
            $ResolvedVersion = Resolve-Version -Version $ManifestData.ModuleVersion
        }
    }

    $ModuleParams = @{
        Name = $ResolvedName
        Version = $ResolvedVersion
        Path = $ResolvedPath
        ManifestPath = $ManifestPath
        LoadedInstance = $LoadedInstance
    }
    New-NitpickModule @ModuleParams
}
