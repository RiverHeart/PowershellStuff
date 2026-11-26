using namespace System.IO

<#
.SYNOPSIS
    Runs suite coverage and optionally enforces a new-code coverage gate.

.DESCRIPTION
    Executes coverage through Invoke-MDKTest and supports an optional new-code
    gate via Invoke-MDKNewCodeGate. Coverage mode can be selected explicitly
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
    Enables debug output in Invoke-MDKTest.

.PARAMETER DetailedOutput
    Enables detailed output in Invoke-MDKTest.

.PARAMETER ShowPassed
    Shows passing tests in Invoke-MDKTest summary.

.EXAMPLE
    Invoke-MDKTestCoverage -TestSuite Example

.EXAMPLE
    Invoke-MDKTestCoverage `
        -TestSuite Example `
        -CoverageMode NewCodeAnalysis `
        -BaseRef origin/main
#>
function Invoke-MDKTestCoverage {
    [CmdletBinding()]
    param(
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

        $suiteConfigPath = if ([Path]::IsPathRooted([string] $suite[0].ConfigPath)) {
            [string] $suite[0].ConfigPath
        } else {
            Join-Path -Path $repoRoot -ChildPath ([string] $suite[0].ConfigPath)
        }

        $suiteConfig = Read-JsonFile -Path $suiteConfigPath -Description 'Suite config'
        $effectiveCoverageMode = Resolve-EffectiveCoverageMode `
            -RequestedMode $CoverageMode `
            -SuiteConfig $suiteConfig

        $coverageOutputPath = Resolve-CoverageOutputPath `
            -SuiteConfig $suiteConfig `
            -RepositoryRoot $repoRoot `
            -TestSuite $TestSuite

        $invokeTestParameters = @{
            TestSuite = $TestSuite
            CoverageMode = 'Full'
            PassThru = $true
            ErrorAction = 'Stop'
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
        [void] (Invoke-MDKTest @invokeTestParameters)

        if ($effectiveCoverageMode -eq 'NewCodeAnalysis') {
            Write-Host ("Running new-code coverage gate using baseline '{0}'..." -f $BaseRef)
            $invokeGateParameters = @{
                BaseRef = $BaseRef
                CoveragePath = $coverageOutputPath
                MinimumCoveragePercent = $MinimumCoveragePercent
                IncludePattern = @($IncludePattern)
                ExcludePathRegex = @($ExcludePathRegex)
            }

            Invoke-MDKNewCodeGate @invokeGateParameters
        }
    } catch {
        throw
    }
}
