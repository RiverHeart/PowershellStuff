using namespace System
using namespace System.IO

<#
.SYNOPSIS
    Builds a PowerShell resource package from project metadata.

.DESCRIPTION
    Loads a project.psd1 file, copies the literal paths listed in Package.Include
    to a temporary staging directory, validates the module manifest, and invokes
    Compress-PSResource. Included directories are copied recursively. When the
    project is inside a Git worktree, files matched by Git ignore rules are
    omitted from the package even when their path is included explicitly. If
    ignore files are present but Git is unavailable, the user is prompted before
    packaging continues without ignore filtering.

.PARAMETER ProjectPath
    Path to the project.psd1 file that defines Name and Package.Include.

.PARAMETER DestinationPath
    Directory where the generated NuGet package is written. Defaults to the
    repository's artifacts/packages directory.

.PARAMETER Force
    Continues without Git ignore filtering when ignore files are present but Git
    cannot be found. Use this only for unattended package builds.

.EXAMPLE
    ./tools/Build-PSResource.ps1 -ProjectPath ./src/modules/PleaseWork/project.psd1
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ProjectPath,

    [ValidateNotNullOrEmpty()]
    [string] $DestinationPath = (Join-Path -Path $PSScriptRoot -ChildPath '../artifacts/packages'),

    [switch] $Force
)

. (Join-Path -Path $PSScriptRoot -ChildPath 'Private\Should-Continue.ps1')

<#
.SYNOPSIS
    Finds Git ignore files that can apply to a project.

.PARAMETER ProjectRoot
    Root directory of the project being packaged.

.EXAMPLE
    Get-GitIgnoreFile -ProjectRoot $PWD
#>
function Get-GitIgnoreFile {
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory)]
        [string] $ProjectRoot
    )

    Get-ChildItem -LiteralPath $ProjectRoot -Filter '.gitignore' -File -Recurse -Force -ErrorAction Stop

    $Parent = Split-Path -Path $ProjectRoot -Parent
    while ($Parent) {
        Get-ChildItem -LiteralPath $Parent -Filter '.gitignore' -File -Force -ErrorAction SilentlyContinue
        $Parent = Split-Path -Path $Parent -Parent
    }
}

<#
.SYNOPSIS
    Finds the Git worktree containing a path.

.PARAMETER Path
    Path beneath the repository to inspect.

.PARAMETER GitExecutable
    Path to the Git executable.

.EXAMPLE
    Get-GitRepositoryRoot -Path $PWD -GitExecutable (Get-Command git).Source
#>
function Get-GitRepositoryRoot {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $GitExecutable
    )

    $RepositoryRoot = & $GitExecutable -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        return
    }

    Write-Output -InputObject (
        [System.IO.Path]::GetFullPath(([string] $RepositoryRoot).Trim())
    ) -NoEnumerate
}

<#
.SYNOPSIS
    Tests whether Git ignore rules match a path.

.PARAMETER Path
    Path to test.

.PARAMETER GitRepositoryRoot
    Root of the Git worktree containing the path.

.PARAMETER GitExecutable
    Path to the Git executable.

.EXAMPLE
    Test-GitIgnoredPath -Path ./build/output.txt -GitRepositoryRoot $PWD -GitExecutable (Get-Command git).Source
#>
function Test-GitIgnoredPath {
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $GitRepositoryRoot,

        [Parameter(Mandatory)]
        [string] $GitExecutable
    )

    & $GitExecutable -C $GitRepositoryRoot check-ignore --quiet --no-index -- $Path
    switch ($LASTEXITCODE) {
        0 { return $true }
        1 { return $false }
        default {
            throw "Git could not evaluate ignore rules for '$Path' (exit code $LASTEXITCODE)."
        }
    }
}

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
$GitIgnoreFiles = @(Get-GitIgnoreFile -ProjectRoot $ProjectRootPath)
$GitCommand = Get-Command -Name 'git' -ErrorAction SilentlyContinue
$GitExecutable = if ($GitCommand) {
    $GitCommand.Source
}
$GitRepositoryRoot = if ($GitExecutable) {
    Get-GitRepositoryRoot -Path $ProjectRootPath -GitExecutable $GitExecutable
}

if ($GitIgnoreFiles.Count -gt 0 -and -not $GitRepositoryRoot) {
    $Warning = if ($GitExecutable) {
        'Git ignore files are present, but Git could not find a worktree containing this project. ' +
            'Continuing may include files that should not be published.'
    } else {
        'Git ignore files are present, but Git was not found on PATH. ' +
            'Continuing may include files that should not be published.'
    }

    if (-not (Should-Continue `
            -Message $Warning `
            -Caption 'Git ignore rules are unavailable' `
            -Force:$Force)
    ) {
        throw 'Package build canceled because Git ignore rules could not be resolved.'
    }
}

$StagingRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "Build-PSResource_$([guid]::NewGuid().ToString('N'))"
$StagingModulePath = Join-Path -Path $StagingRoot -ChildPath ([string] $Project.Name)

try {
    New-Item -Path $StagingModulePath -ItemType Directory -Force -ErrorAction Stop | Out-Null

    foreach ($IncludePath in @($Project.Package.Include)) {
        if ([string]::IsNullOrWhiteSpace([string] $IncludePath)) {
            throw 'Package.Include cannot contain an empty path.'
        }

        if ([Path]::IsPathRooted($IncludePath) -or
            [WildcardPattern]::ContainsWildcardCharacters($IncludePath)
        ) {
            throw "Package include path '$IncludePath' must be a literal path relative to the project directory."
        }

        $SourcePath = [Path]::GetFullPath((Join-Path -Path $ProjectRootPath -ChildPath $IncludePath))
        $IsWithinProject =
            $SourcePath.Equals($ProjectRootPath, [StringComparison]::OrdinalIgnoreCase) -or
            $SourcePath.StartsWith(
                "$ProjectRootPath$([Path]::DirectorySeparatorChar)",
                [StringComparison]::OrdinalIgnoreCase
            )

        if (-not $IsWithinProject) {
            throw "Package include path '$IncludePath' resolves outside the project directory."
        }

        if (-not (Test-Path -LiteralPath $SourcePath)) {
            throw "Package include path '$IncludePath' does not exist beneath '$ProjectRootPath'."
        }

        $SourceItem = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop
        $FilesToCopy = if ($SourceItem.PSIsContainer) {
            Get-ChildItem -LiteralPath $SourcePath -File -Recurse -Force -ErrorAction Stop
        } else {
            $SourceItem
        }

        foreach ($FileToCopy in $FilesToCopy) {
            if ($FileToCopy.Name -ieq '.gitignore') {
                Write-Verbose "Skipping package metadata path '$($FileToCopy.FullName)'."
                continue
            }

            if ($GitRepositoryRoot -and
                (Test-GitIgnoredPath `
                    -Path $FileToCopy.FullName `
                    -GitRepositoryRoot $GitRepositoryRoot `
                    -GitExecutable $GitExecutable)
            ) {
                Write-Verbose "Skipping Git-ignored package path '$($FileToCopy.FullName)'."
                continue
            }

            $RelativePath = $FileToCopy.FullName.Substring($ProjectRootPath.Length).TrimStart('\', '/')
            $StagedPath = Join-Path -Path $StagingModulePath -ChildPath $RelativePath
            $StagedParent = Split-Path -Path $StagedPath -Parent
            New-Item -Path $StagedParent -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Copy-Item -LiteralPath $FileToCopy.FullName -Destination $StagedPath -Force -ErrorAction Stop
        }
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
