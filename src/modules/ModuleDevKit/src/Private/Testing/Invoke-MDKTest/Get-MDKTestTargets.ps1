using namespace System.IO
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Resolves project and suite configurations into runnable test targets.

.DESCRIPTION
    Supports a root project catalog, a project's named suites, or a single Run
    configuration, resolving every configured path relative to its config file.

.PARAMETER RootConfig
    Parsed root Pester configuration.

.PARAMETER RootConfigPath
    Absolute path to the root Pester configuration.

.NOTES
    Examples for this private helper run in the module's scope.
#>
function Get-MDKTestTargets {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object] $RootConfig,

        [Parameter(Mandatory)]
        [string] $RootConfigPath
    )

    $RootDirectory = Split-Path -Path $RootConfigPath -Parent
    $RootName = Split-Path -Path $RootDirectory -Leaf
    $Targets = [List[object]]::new()

    $AddSuiteTarget = {
        param(
            [Parameter(Mandatory)]
            [object] $Suite,

            [Parameter(Mandatory)]
            [string] $ProjectName,

            [Parameter(Mandatory)]
            [string] $ConfigDirectory,

            [Parameter(Mandatory)]
            [string] $ParentConfigPath
        )

        $HasConfigPath = (
            ($Suite.PSObject.Properties.Name -contains 'ConfigPath') -and
            -not [string]::IsNullOrWhiteSpace([string] $Suite.ConfigPath)
        )

        if ($HasConfigPath) {
            $SuiteConfigPath = if ([Path]::IsPathRooted([string] $Suite.ConfigPath)) {
                [string] $Suite.ConfigPath
            } else {
                Join-Path -Path $ConfigDirectory -ChildPath ([string] $Suite.ConfigPath)
            }

            if (-not (Test-Path -LiteralPath $SuiteConfigPath -PathType Leaf)) {
                throw "Test suite config was not found: $SuiteConfigPath"
            }

            $SuiteConfig = Read-JsonFile -Path $SuiteConfigPath -Description 'Test suite config'
            Test-SuiteManifest -SuiteConfig $SuiteConfig -Path $SuiteConfigPath
            $SuiteBaseDirectory = Split-Path -Path $SuiteConfigPath -Parent
        } else {
            $SuiteConfigPath = $ParentConfigPath
            $SuiteConfig = $Suite
            Test-SuiteManifest `
                -SuiteConfig $SuiteConfig `
                -Path "$ParentConfigPath (test suite '$($Suite.Name)')"
            $SuiteBaseDirectory = $ConfigDirectory
        }

        $Targets.Add([pscustomobject]@{
            ProjectName       = $ProjectName
            TestSuiteName     = [string] $Suite.Name
            ConfigPath        = $SuiteConfigPath
            Config            = $SuiteConfig
            BaseDirectory     = $SuiteBaseDirectory
        })
    }

    $AddProjectConfig = {
        param(
            [Parameter(Mandatory)]
            [object] $Project,

            [Parameter(Mandatory)]
            [string] $ProjectConfigPath
        )

        $ProjectConfig = Read-JsonFile -Path $ProjectConfigPath -Description 'Project test config'
        $ProjectConfigDirectory = Split-Path -Path $ProjectConfigPath -Parent
        $HasTestSuites = $ProjectConfig.PSObject.Properties.Name -contains 'TestSuites'
        $HasRun = (
            ($ProjectConfig.PSObject.Properties.Name -contains 'Run') -and
            $null -ne $ProjectConfig.Run
        )

        if ($HasTestSuites -and $HasRun) {
            throw "Project config '$ProjectConfigPath' cannot define both TestSuites and Run."
        }

        if ($HasTestSuites) {
            Test-MDKTestSuiteCollection `
                -TestSuites @($ProjectConfig.TestSuites) `
                -Path $ProjectConfigPath

            foreach ($Suite in @($ProjectConfig.TestSuites)) {
                & $AddSuiteTarget `
                    -Suite $Suite `
                    -ProjectName ([string] $Project.Name) `
                    -ConfigDirectory $ProjectConfigDirectory `
                    -ParentConfigPath $ProjectConfigPath
            }
        } elseif ($HasRun) {
            Test-SuiteManifest -SuiteConfig $ProjectConfig -Path $ProjectConfigPath
            $TestSuiteName = if (
                ($ProjectConfig.PSObject.Properties.Name -contains 'TestSuite') -and
                -not [string]::IsNullOrWhiteSpace([string] $ProjectConfig.TestSuite)
            ) {
                [string] $ProjectConfig.TestSuite
            } else {
                ''
            }

            $Targets.Add([pscustomobject]@{
                ProjectName   = [string] $Project.Name
                TestSuiteName = $TestSuiteName
                ConfigPath    = $ProjectConfigPath
                Config        = $ProjectConfig
                BaseDirectory = $ProjectConfigDirectory
            })
        } else {
            throw "Project config '$ProjectConfigPath' must define Run or TestSuites."
        }
    }

    if ($RootConfig.PSObject.Properties.Name -contains 'Projects') {
        foreach ($Project in @($RootConfig.Projects)) {
            $ProjectConfigPath = if ([Path]::IsPathRooted([string] $Project.ConfigPath)) {
                [string] $Project.ConfigPath
            } else {
                Join-Path -Path $RootDirectory -ChildPath ([string] $Project.ConfigPath)
            }

            if (-not (Test-Path -LiteralPath $ProjectConfigPath -PathType Leaf)) {
                throw "Project config was not found: $ProjectConfigPath"
            }

            & $AddProjectConfig -Project $Project -ProjectConfigPath $ProjectConfigPath
        }
    } elseif ($RootConfig.PSObject.Properties.Name -contains 'TestSuites') {
        Test-MDKTestSuiteCollection `
            -TestSuites @($RootConfig.TestSuites) `
            -Path $RootConfigPath

        foreach ($Suite in @($RootConfig.TestSuites)) {
            & $AddSuiteTarget `
                -Suite $Suite `
                -ProjectName $RootName `
                -ConfigDirectory $RootDirectory `
                -ParentConfigPath $RootConfigPath
        }
    } elseif (
        ($RootConfig.PSObject.Properties.Name -contains 'Run') -and
        $null -ne $RootConfig.Run
    ) {
        Test-SuiteManifest -SuiteConfig $RootConfig -Path $RootConfigPath
        $TestSuiteName = if (
            ($RootConfig.PSObject.Properties.Name -contains 'TestSuite') -and
            -not [string]::IsNullOrWhiteSpace([string] $RootConfig.TestSuite)
        ) {
            [string] $RootConfig.TestSuite
        } else {
            ''
        }

        $Targets.Add([pscustomobject]@{
            ProjectName   = $RootName
            TestSuiteName = $TestSuiteName
            ConfigPath    = $RootConfigPath
            Config        = $RootConfig
            BaseDirectory = $RootDirectory
        })
    } else {
        throw "Root config '$RootConfigPath' must define Projects, TestSuites, or Run."
    }

    return @($Targets)
}
