<#
.SYNOPSIS
    Runs suite coverage and optionally enforces a new-code coverage gate.

.DESCRIPTION
    Executes coverage through Invoke-Test.ps1 and supports an optional new-code
    gate via Invoke-NewCodeGate.ps1. Coverage mode can be selected explicitly
    or read from suite config Coverage.Mode.

.PARAMETER TestSuite
    Name of the configured test suite.

.PARAMETER CoverageMode
    Coverage execution mode:
    - Full: run coverage only.
    - NewCodeAnalysis: run coverage, then evaluate new-code coverage gate.
    - FromConfig: read Coverage.Mode from suite config, defaulting to Full when absent.

.PARAMETER BaseRef
    Git baseline reference used for new-code analysis.

.PARAMETER MinimumCoveragePercent
    Minimum required new-code coverage percent.

.PARAMETER IncludePattern
    Git pathspec patterns used to select changed files for new-code analysis.

.PARAMETER ExcludePathRegex
    Regex patterns used to exclude changed files from new-code analysis.

.PARAMETER Tag
    Optional Pester include tags.

.PARAMETER ExcludeTag
    Optional Pester exclude tags.

.PARAMETER DebugOutput
    Enables debug output in Invoke-Test.

.PARAMETER DetailedOutput
    Enables detailed output in Invoke-Test.

.PARAMETER ShowPassed
    Shows passing tests in Invoke-Test summary.

.EXAMPLE
    ./.github/skills/test-runner/scripts/Invoke-TestCoverage.ps1 -TestSuite WPF

.EXAMPLE
    ./.github/skills/test-runner/scripts/Invoke-TestCoverage.ps1 -TestSuite WPF -CoverageMode NewCodeAnalysis -BaseRef origin/main
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $TestSuite,

    [ValidateSet('FromConfig', 'Full', 'NewCodeAnalysis')]
    [string] $CoverageMode = 'FromConfig',

    [ValidateNotNullOrEmpty()]
    [string] $BaseRef = 'origin/main',

    [ValidateRange(0, 100)]
    [double] $MinimumCoveragePercent = 80,

    [ValidateNotNullOrEmpty()]
    [string[]] $IncludePattern = @('*.ps1', '*.psm1'),

    [ValidateNotNullOrEmpty()]
    [string[]] $ExcludePathRegex = @(
        '(?i)^\.github\\',
        '(?i)\\tests?\\',
        '(?i)\.tests\.ps1$'
    ),

    [string[]] $Tag,
    [string[]] $ExcludeTag,
    [switch] $DebugOutput,
    [switch] $DetailedOutput,
    [switch] $ShowPassed
)

function Get-RepositoryRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $StartDirectories
    )

    foreach ($startDirectory in $StartDirectories) {
        if (-not [string]::IsNullOrWhiteSpace($startDirectory)) {
            $candidate = Resolve-Path -Path $startDirectory -ErrorAction SilentlyContinue
            if ($null -eq $candidate) {
                continue
            }

            $current = $candidate.Path
            while ($current -ne [System.IO.Path]::GetPathRoot($current)) {
                $rootConfigPath = Join-Path $current 'pester.json'
                if (Test-Path -Path $rootConfigPath) {
                    try {
                        $rootConfig = Get-Content -Path $rootConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
                        if ($rootConfig.PSObject.Properties.Name -contains 'isRoot' -and [bool] $rootConfig.isRoot) {
                            return $current
                        }
                    } catch {
                    }
                }

                if (Test-Path -Path (Join-Path $current '.git')) {
                    return $current
                }

                $parent = Split-Path -Path $current -Parent
                if ($parent -eq $current) {
                    break
                }

                $current = $parent
            }
        }
    }

    return $null
}

function Read-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Description
    )

    if (-not (Test-Path -Path $Path)) {
        throw "$Description was not found: $Path"
    }

    try {
        return (Get-Content -Path $Path -Raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        throw "Failed to parse $Description '$Path': $_"
    }
}

function Resolve-CoverageOutputPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $SuiteConfig,

        [Parameter(Mandatory)]
        [string] $RepositoryRoot,

        [Parameter(Mandatory)]
        [string] $TestSuite
    )

    if (
        ($SuiteConfig.Coverage.PSObject.Properties.Name -contains 'OutputPath') -and
        -not [string]::IsNullOrWhiteSpace([string] $SuiteConfig.Coverage.OutputPath)
    ) {
        $configuredOutputPath = [string] $SuiteConfig.Coverage.OutputPath
        if ([System.IO.Path]::IsPathRooted($configuredOutputPath)) {
            return $configuredOutputPath
        }

        return (Join-Path -Path $RepositoryRoot -ChildPath $configuredOutputPath)
    }

    return (Join-Path -Path $RepositoryRoot -ChildPath ("artifacts/coverage/{0}.coverage.xml" -f $TestSuite))
}

function Resolve-EffectiveCoverageMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RequestedMode,

        [Parameter(Mandatory)]
        [object] $SuiteConfig
    )

    if ($RequestedMode -ne 'FromConfig') {
        return $RequestedMode
    }

    if (
        ($SuiteConfig.PSObject.Properties.Name -contains 'Coverage') -and
        $null -ne $SuiteConfig.Coverage -and
        ($SuiteConfig.Coverage.PSObject.Properties.Name -contains 'Mode') -and
        -not [string]::IsNullOrWhiteSpace([string] $SuiteConfig.Coverage.Mode)
    ) {
        $configMode = [string] $SuiteConfig.Coverage.Mode
        switch -Regex ($configMode) {
            '^(?i)full$' { return 'Full' }
            '^(?i)new[-_]?code[-_]?analysis$' { return 'NewCodeAnalysis' }
            default {
                throw "Unsupported Coverage.Mode '$configMode'. Use Full or NewCodeAnalysis."
            }
        }
    }

    return 'Full'
}

try {
    $repoRoot = Get-RepositoryRoot -StartDirectories @((Get-Location).Path, $PSScriptRoot)
    if ($null -eq $repoRoot) {
        throw 'Could not locate repository root. Add a pester.json file with isRoot=true or ensure .git exists.'
    }

    $rootConfigPath = Join-Path -Path $repoRoot -ChildPath 'pester.json'
    $rootConfig = Read-JsonFile -Path $rootConfigPath -Description 'Root test config'

    $suite = @($rootConfig.TestSuites | Where-Object { $_.Name -eq $TestSuite } | Select-Object -First 1)
    if ($suite.Count -eq 0) {
        $availableSuites = @($rootConfig.TestSuites | ForEach-Object { $_.Name }) -join ', '
        throw "Unknown test suite '$TestSuite'. Available suites: $availableSuites"
    }

    $suiteConfigPath = if ([System.IO.Path]::IsPathRooted([string] $suite[0].ConfigPath)) {
        [string] $suite[0].ConfigPath
    } else {
        Join-Path -Path $repoRoot -ChildPath ([string] $suite[0].ConfigPath)
    }

    $suiteConfig = Read-JsonFile -Path $suiteConfigPath -Description 'Suite config'
    $effectiveCoverageMode = Resolve-EffectiveCoverageMode -RequestedMode $CoverageMode -SuiteConfig $suiteConfig
    $coverageOutputPath = Resolve-CoverageOutputPath -SuiteConfig $suiteConfig -RepositoryRoot $repoRoot -TestSuite $TestSuite

    $invokeTestScript = Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-Test.ps1'
    $invokeTestParameters = @{
        TestSuite = $TestSuite
        CoverageMode = 'Full'
    }

    if ($null -ne $Tag -and $Tag.Count -gt 0) {
        $invokeTestParameters.Tag = @($Tag)
    }

    if ($null -ne $ExcludeTag -and $ExcludeTag.Count -gt 0) {
        $invokeTestParameters.ExcludeTag = @($ExcludeTag)
    }

    if ($DebugOutput) {
        $invokeTestParameters.DebugOutput = $true
    }

    if ($DetailedOutput) {
        $invokeTestParameters.DetailedOutput = $true
    }

    if ($ShowPassed) {
        $invokeTestParameters.ShowPassed = $true
    }

    Write-Host ("Coverage Mode: {0}" -f $effectiveCoverageMode)
    Write-Host ("Running coverage for suite '{0}'..." -f $TestSuite)
    & $invokeTestScript @invokeTestParameters
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    if ($effectiveCoverageMode -eq 'NewCodeAnalysis') {
        $invokeGateScript = Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-NewCodeGate.ps1'
        Write-Host ("Running new-code coverage gate using baseline '{0}'..." -f $BaseRef)
        $invokeGateParameters = @{
            BaseRef = $BaseRef
            CoveragePath = $coverageOutputPath
            MinimumCoveragePercent = $MinimumCoveragePercent
            IncludePattern = @($IncludePattern)
            ExcludePathRegex = @($ExcludePathRegex)
        }
        & $invokeGateScript @invokeGateParameters

        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    exit 0
} catch {
    Write-Error $_
    exit 2
}
