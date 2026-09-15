<#
.SYNOPSIS
    Starts a WPF application entry point inside an application module's scope.

.DESCRIPTION
    Imports an application module and dot-sources an entry point in that module's
    session state. The entry point can therefore call functions that the application
    module does not export.

.PARAMETER ModulePath
    Path to the application module manifest or script module.

.PARAMETER EntryPoint
    Path to the application entry point, relative to the application module root.

.PARAMETER Force
    Forces the application module to reload before running the entry point.

.EXAMPLE
    Start-WPFApplication -ModulePath ./MyApp.psd1 -EntryPoint src/Views/main.gui.ps1 -Force
#>
function Start-WPFApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModulePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $EntryPoint,

        [switch] $Force
    )

    if ([System.IO.Path]::IsPathRooted($EntryPoint)) {
        throw "Entry point '$EntryPoint' must be relative to the application module root."
    }

    $ResolvedModulePath = Resolve-Path -LiteralPath $ModulePath -ErrorAction Stop
    $ApplicationModules = @(
        Import-Module -Name $ResolvedModulePath.ProviderPath -PassThru -Force:$Force -ErrorAction Stop
    )

    if ($ApplicationModules.Count -ne 1) {
        throw "Application module '$ModulePath' resolved to $($ApplicationModules.Count) modules; expected exactly one."
    }

    $ApplicationModule = $ApplicationModules[0]
    $ModuleRoot = [System.IO.Path]::GetFullPath($ApplicationModule.ModuleBase).TrimEnd('\', '/')
    $CandidateEntryPoint = [System.IO.Path]::GetFullPath((Join-Path $ModuleRoot $EntryPoint))

    if (-not (Test-Path -LiteralPath $CandidateEntryPoint -PathType Leaf)) {
        throw "Application entry point '$CandidateEntryPoint' was not found."
    }

    $ResolvedEntryPoint = (Resolve-Path -LiteralPath $CandidateEntryPoint -ErrorAction Stop).ProviderPath
    $ModuleRootPrefix = $ModuleRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $ResolvedEntryPoint.StartsWith($ModuleRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Application entry point '$ResolvedEntryPoint' is outside module root '$ModuleRoot'."
    }

    & $ApplicationModule {
        param($Path)

        . $Path
    } $ResolvedEntryPoint
}
