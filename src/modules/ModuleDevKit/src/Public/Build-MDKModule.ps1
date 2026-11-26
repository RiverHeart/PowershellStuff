using namespace System
using namespace System.IO

<#
.SYNOPSIS
    Builds a PowerShell resource package from project metadata.

.DESCRIPTION
    Loads a project.psd1 file, copies the literal paths listed in Package.Include
    to a temporary staging directory, validates the module manifest, and invokes
    Compress-MDKModule. Included directories are copied recursively. When the
    project is inside a Git worktree, files matched by Git ignore rules are
    omitted from the package even when their path is included explicitly. If
    ignore files are present but Git is unavailable, the user is prompted before
    packaging continues without ignore filtering.

.NOTES
    `Invoke-MDKModuleBuild` is the canonical name only because `Build` isn't a
    recognized verb in PowerShell Desktop Edition because of the abject stupidity
    of enforcing verb naming rules in `Import-Module. `Build-MDKModule` is the
    intended public command name.

.PARAMETER ProjectPath
    Path to the project.psd1 file that defines Name and Package.Include.

.PARAMETER DestinationPath
    Directory where the generated NuGet package is written. Defaults to the
    repository's artifacts/packages directory.

.PARAMETER Force
    Continues without Git ignore filtering when ignore files are present but Git
    cannot be found. Use this only for unattended package builds.

.EXAMPLE
    Build-MDKModule -ProjectPath ./src/modules/project/project.psd1
#>
function Invoke-MDKModuleBuild {
    [CmdletBinding()]
    [Alias('Build-MDKModule')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ProjectPath,

        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath = (Join-Path -Path $PSScriptRoot -ChildPath '../artifacts/packages'),

        [switch] $Force
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

    Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop | Out-Null

    $ProjectRootPath = [Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/')
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

    $StagingRoot = Join-Path -Path ([Path]::GetTempPath()) -ChildPath "Build-PSResource_$([guid]::NewGuid().ToString('N'))"
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

        $ResolvedDestinationPath = [Path]::GetFullPath($DestinationPath)
        New-Item -Path $ResolvedDestinationPath -ItemType Directory -Force -ErrorAction Stop | Out-Null

        Compress-MDKModule `
            -ModulePath $StagingModulePath `
            -OutputPath $ResolvedDestinationPath `
            -PassThru `
            -ErrorAction Stop
    } finally {
        if (Test-Path -LiteralPath $StagingRoot) {
            Remove-Item -LiteralPath $StagingRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
