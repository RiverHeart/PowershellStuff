using namespace System
using namespace System.IO
using namespace System.Management.Automation.Host

<#
.SYNOPSIS
    Builds a PowerShell resource package from project metadata.

.DESCRIPTION
    Loads a project.psd1 file to identify the module, validates that the module
    manifest FileList contains literal file paths, and copies those files to a
    temporary staging directory before invoking Compress-MDKModule. The module
    manifest itself is always staged. When the project is inside a Git worktree,
    files matched by Git ignore rules are omitted from the package even when
    their path is listed explicitly. If ignore files are present but Git is
    unavailable, the user is prompted before packaging continues without ignore
    filtering.

.NOTES
    `Invoke-MDKModuleBuild` is the canonical name only because `Build` isn't a
    recognized verb in PowerShell Desktop Edition because of the abject stupidity
    of enforcing verb naming rules in `Import-Module. `Build-MDKModule` is the
    intended public command name.

.PARAMETER ProjectPath
    Path to the project.psd1 file that defines Name.

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
        [ValidateNotNullOrEmpty()]
        [string] $ProjectPath = $PWD,

        [ValidateNotNullOrEmpty()]
        [string] $DestinationPath,

        [switch] $Force
    )

    $ProjectPathResolved = Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop
    if ((Test-Path $ProjectPathResolved -PathType Container)) {
        $ProjectFile = Join-Path -Path $ProjectPathResolved -ChildPath 'project.psd1'
    } else {
        $ProjectFile = $ProjectPathResolved
    }
    $ProjectRoot = Split-Path -Path $ProjectFile -Parent

    if (-not $DestinationPath) {
        $DestinationPath = Join-Path -Path $ProjectRoot -ChildPath './artifacts/packages'
    }

    if (-not (Test-Path $ProjectPathResolved -PathType Leaf)) {
        $Title = 'Project.psd1 file missing'
        $Message = "The project.psd1 file is missing at '$ProjectPathResolved'. Would you like to create it?"
        $Options = [ChoiceDescription[]]@(
            [ChoiceDescription]::new('&Yes', 'Create a new project.psd1 file.'),
            [ChoiceDescription]::new('&No', 'Abort operation.')
        )

        $UserChoice = $Host.UI.PromptForChoice($Title, $Message, $Options, 0)
        if ($UserChoice -eq 0) {
            $ProjectName = Split-Path -Path $ProjectRoot -Leaf
            $ProjectFileTemplate = "$script:ModuleRoot/src/Data/Templates/project.psd1"
            (Get-Content $ProjectFileTemplate) -replace '__ModuleName__', $ProjectName |
                    Out-File -FilePath $ProjectFile -Force
        } else {
            Write-Error 'Project.psd1 creation declined by user. Exiting.'
            return
        }
    }

    $Project = Import-PowerShellDataFile -LiteralPath $ProjectFile -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace([string] $Project.Name)) {
        throw "Project metadata '$ProjectFile' must define a non-empty Name."
    }

    $ManifestPath = Join-Path -Path $ProjectRoot -ChildPath "$($Project.Name).psd1"
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Module manifest not found at '$ManifestPath'."
    }

    $ModuleManifest = Import-PowerShellDataFile -LiteralPath $ManifestPath -ErrorAction Stop
    if (-not $ModuleManifest.FileList -or @($ModuleManifest.FileList).Count -eq 0) {
        throw "Module manifest '$ManifestPath' must define a non-empty FileList."
    }

    $ProjectRootPath = [Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/')
    $ManifestFiles = foreach ($IncludePath in @($ModuleManifest.FileList)) {
        if ([string]::IsNullOrWhiteSpace([string] $IncludePath)) {
            throw 'Module manifest FileList cannot contain an empty path.'
        }

        if ([Path]::IsPathRooted($IncludePath) -or
            [WildcardPattern]::ContainsWildcardCharacters($IncludePath)
        ) {
            throw "Module manifest FileList path '$IncludePath' must be a literal path relative to the module directory."
        }

        $SourcePath = [Path]::GetFullPath((Join-Path -Path $ProjectRootPath -ChildPath $IncludePath))
        $IsWithinProject =
            $SourcePath.Equals($ProjectRootPath, [StringComparison]::OrdinalIgnoreCase) -or
            $SourcePath.StartsWith(
                "$ProjectRootPath$([Path]::DirectorySeparatorChar)",
                [StringComparison]::OrdinalIgnoreCase
            )

        if (-not $IsWithinProject) {
            throw "Module manifest FileList path '$IncludePath' resolves outside the module directory."
        }

        if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
            throw "Module manifest FileList path '$IncludePath' is not a file beneath '$ProjectRootPath'."
        }

        [pscustomobject]@{
            RelativePath = [string] $IncludePath
            SourceItem = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop
        }
    }

    Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop | Out-Null

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

    $StagingRoot = Join-Path `
        -Path ([Path]::GetTempPath()) `
        -ChildPath "Build-PSResource_$([guid]::NewGuid().ToString('N'))"

    $StagingModulePath = Join-Path -Path $StagingRoot -ChildPath ([string] $Project.Name)

    try {
        New-Item -Path $StagingModulePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Copy-Item -LiteralPath $ManifestPath -Destination $StagingModulePath -Force -ErrorAction Stop
        $StagedFileList = @("$($Project.Name).psd1")
        $IgnoredStagedPaths = @()

        foreach ($ManifestFile in $ManifestFiles) {
            $SourceItem = $ManifestFile.SourceItem
            if ($SourceItem.FullName.Equals($ManifestPath, [StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            $IsIgnored = $false
            if ($SourceItem.Name -ieq '.gitignore') {
                Write-Verbose "Skipping package metadata path '$($SourceItem.FullName)'."
                $IsIgnored = $true
            }

            if ($GitRepositoryRoot -and
                (Test-GitIgnoredPath `
                    -Path $SourceItem.FullName `
                    -GitRepositoryRoot $GitRepositoryRoot `
                    -GitExecutable $GitExecutable)
            ) {
                Write-Verbose "Skipping Git-ignored package path '$($SourceItem.FullName)'."
                $IsIgnored = $true
            }

            $RelativePath = $SourceItem.FullName.Substring($ProjectRootPath.Length).TrimStart('\', '/')
            $StagedPath = Join-Path -Path $StagingModulePath -ChildPath $RelativePath
            $StagedParent = Split-Path -Path $StagedPath -Parent
            New-Item -Path $StagedParent -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Copy-Item -LiteralPath $SourceItem.FullName -Destination $StagedPath -Force -ErrorAction Stop

            if ($IsIgnored) {
                $IgnoredStagedPaths += $StagedPath
            } else {
                $StagedFileList += $ManifestFile.RelativePath
            }
        }

        $StagedManifestPath = Join-Path -Path $StagingModulePath -ChildPath "$($Project.Name).psd1"
        Update-ModuleManifest `
            -Path $StagedManifestPath `
            -FileList $StagedFileList `
            -ErrorAction Stop

        foreach ($IgnoredStagedPath in $IgnoredStagedPaths) {
            Remove-Item -LiteralPath $IgnoredStagedPath -Force -ErrorAction Stop
        }

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
