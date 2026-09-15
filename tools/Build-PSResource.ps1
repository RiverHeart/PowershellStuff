<#
.SYNOPSIS
    Builds a PowerShell resource package from project metadata.

.DESCRIPTION
    Loads a project.psd1 file, copies the literal paths listed in Package.Include
    to a temporary staging directory, validates the module manifest, and invokes
    Compress-PSResource. Included directories are copied recursively.

.PARAMETER ProjectPath
    Path to the project.psd1 file that defines Name and Package.Include.

.PARAMETER DestinationPath
    Directory where the generated NuGet package is written. Defaults to the
    repository's artifacts/packages directory.

.EXAMPLE
    ./tools/Build-PSResource.ps1 -ProjectPath ./src/modules/PleaseWork/project.psd1
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ProjectPath,

    [ValidateNotNullOrEmpty()]
    [string] $DestinationPath = (Join-Path -Path $PSScriptRoot -ChildPath '../artifacts/packages')
)

$ProjectFile = Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop
$ProjectRoot = Split-Path -Path $ProjectFile.Path -Parent
$Project = Import-PowerShellDataFile -LiteralPath $ProjectFile.Path -ErrorAction Stop

if ([string]::IsNullOrWhiteSpace([string] $Project.Name)) {
    throw "Project metadata '$($ProjectFile.Path)' must define a non-empty Name."
}

if (-not $Project.Package -or -not $Project.Package.Include) {
    throw "Project metadata '$($ProjectFile.Path)' must define Package.Include."
}

$ManifestPath = Join-Path -Path $ProjectRoot -ChildPath "$($Project.Name).psd1"
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Module manifest not found at '$ManifestPath'."
}

$CompressCommand = Get-Command -Name 'Compress-PSResource' -ErrorAction SilentlyContinue
if (-not $CompressCommand) {
    throw 'Compress-PSResource was not found. Install Microsoft.PowerShell.PSResourceGet before building.'
}

Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop | Out-Null

$ProjectRootPath = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/')
$StagingRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "Build-PSResource_$([guid]::NewGuid().ToString('N'))"
$StagingModulePath = Join-Path -Path $StagingRoot -ChildPath ([string] $Project.Name)

try {
    New-Item -Path $StagingModulePath -ItemType Directory -Force -ErrorAction Stop | Out-Null

    foreach ($IncludePath in @($Project.Package.Include)) {
        if ([string]::IsNullOrWhiteSpace([string] $IncludePath)) {
            throw 'Package.Include cannot contain an empty path.'
        }

        if ([System.IO.Path]::IsPathRooted($IncludePath) -or [WildcardPattern]::ContainsWildcardCharacters($IncludePath)) {
            throw "Package include path '$IncludePath' must be a literal path relative to the project directory."
        }

        $SourcePath = [System.IO.Path]::GetFullPath((Join-Path -Path $ProjectRootPath -ChildPath $IncludePath))
        $IsWithinProject = $SourcePath.Equals($ProjectRootPath, [System.StringComparison]::OrdinalIgnoreCase) -or
            $SourcePath.StartsWith("$ProjectRootPath$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase)
        if (-not $IsWithinProject) {
            throw "Package include path '$IncludePath' resolves outside the project directory."
        }

        if (-not (Test-Path -LiteralPath $SourcePath)) {
            throw "Package include path '$IncludePath' does not exist beneath '$ProjectRootPath'."
        }

        $StagedPath = Join-Path -Path $StagingModulePath -ChildPath $IncludePath
        $StagedParent = Split-Path -Path $StagedPath -Parent
        New-Item -Path $StagedParent -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Copy-Item -LiteralPath $SourcePath -Destination $StagedPath -Recurse -Force -ErrorAction Stop
    }

    $StagedManifestPath = Join-Path -Path $StagingModulePath -ChildPath "$($Project.Name).psd1"
    Test-ModuleManifest -Path $StagedManifestPath -ErrorAction Stop | Out-Null

    $ResolvedDestinationPath = [System.IO.Path]::GetFullPath($DestinationPath)
    New-Item -Path $ResolvedDestinationPath -ItemType Directory -Force -ErrorAction Stop | Out-Null

    Compress-PSResource `
        -Path $StagingModulePath `
        -DestinationPath $ResolvedDestinationPath `
        -PassThru `
        -ErrorAction Stop
} finally {
    if (Test-Path -LiteralPath $StagingRoot) {
        Remove-Item -LiteralPath $StagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
