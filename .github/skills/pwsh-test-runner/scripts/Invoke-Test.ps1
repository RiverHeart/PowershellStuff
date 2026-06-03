<#
.SYNOPSIS
    Runs Pester tests with compact, failure-focused output using suite configuration.

.DESCRIPTION
    Invokes Pester using PassThru so results can be summarized without parsing noisy console output.
    By default, only failing or non-passing tests are printed, followed by stable summary lines:

    Tests completed in <seconds>s
    Tests Passed: X, Failed: Y, Skipped: Z, Inconclusive: A, NotRun: B

    Debug preference is scoped to this script invocation and restored in a finally block.

.NOTES
    This is geared towards agent use to reduce token consumption and provide a clear
    summary of test results.

    TODO: Rather than trying to get the Agent to follow a specific workflow, I should
    explore using test result history and last successful commit to automatically determine
    which tests to run for a given change. The agent can then be given more generic instructions
    to run the script until all tests are passing. Additionally, I need to figure out how to
    require coverage for code so that the agent doesn't forget to add a test for new code.

.PARAMETER TestSuite
    Name of the configured test suite to run.

.PARAMETER ListSuites
    Lists configured test suites and exits.

.PARAMETER ListTags
    Lists discovered tags for the selected test suite and exits.

.PARAMETER Tag
    Optional list of tags to include.

.PARAMETER ExcludeTag
    Optional list of tags to exclude.

.PARAMETER DebugOutput
    Enables debug output only for this invocation.

.PARAMETER ShowPassed
    Also prints passing tests in addition to non-passing tests.

.PARAMETER DetailedOutput
    Enables detailed Pester console output. By default, compact summary output is used.

.PARAMETER CoverageMode
    Coverage execution mode.
    - None: run tests without coverage (default).
    - Full: run tests with configured coverage settings.

.PARAMETER PassThru
    Returns the full Pester result object after printing the summary.

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -TestSuite Example

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -DebugOutput

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -TestSuite Example -Tag DataGrid -PassThru

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -TestSuite Example -CoverageMode Full

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -TestSuite Example -DetailedOutput

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -ListSuites

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -TestSuite Example -ListTags
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory, ParameterSetName = 'Run')]
    [Parameter(Mandatory, ParameterSetName = 'ListTags')]
    [ValidateNotNullOrEmpty()]
    [string] $TestSuite,

    [Parameter(Mandatory, ParameterSetName = 'List')]
    [switch] $ListSuites,

    [Parameter(Mandatory, ParameterSetName = 'ListTags')]
    [switch] $ListTags,

    [Parameter(ParameterSetName = 'Run')]
    [string[]] $Tag,

    [Parameter(ParameterSetName = 'Run')]
    [string[]] $ExcludeTag,

    [switch] $DebugOutput,
    [switch] $ShowPassed,
    [switch] $DetailedOutput,
    [Parameter(ParameterSetName = 'Run')]
    [ValidateSet('None', 'Full')]
    [string] $CoverageMode = 'None',
    [switch] $PassThru
)

$loadedPester = Get-Module -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if ($null -ne $loadedPester -and $loadedPester.Version.Major -lt 5) {
    Write-Error (
        "Pester 5 or newer is required. Currently loaded version is $($loadedPester.Version). " +
        'Remove the loaded module and run again.'
    )
    exit 2
}

if ($null -eq $loadedPester) {
    $pesterModule = Get-Module -ListAvailable -Name Pester |
        Sort-Object Version -Descending |
        Where-Object { $_.Version.Major -ge 5 } |
        Select-Object -First 1
    if ($null -eq $pesterModule) {
        Write-Error 'Pester module was not found. Install Pester 5 or newer to run tests.'
        exit 2
    }

    Import-Module -Name $pesterModule.Path -ErrorAction Stop
}

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
                        Write-Debug "Ignoring invalid root config at '$rootConfigPath': $_"
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

function Test-RootManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $RootConfig,

        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not ($RootConfig.PSObject.Properties.Name -contains 'isRoot') -or -not [bool] $RootConfig.isRoot) {
        throw "Root config '$Path' must contain isRoot=true."
    }

    if (-not ($RootConfig.PSObject.Properties.Name -contains 'TestSuites')) {
        throw "Root config '$Path' is missing TestSuites."
    }

    $suites = @($RootConfig.TestSuites)
    if ($suites.Count -eq 0) {
        throw "Root config '$Path' must define at least one suite in TestSuites."
    }

    foreach ($suite in $suites) {
        if (-not ($suite.PSObject.Properties.Name -contains 'Name') -or [string]::IsNullOrWhiteSpace([string] $suite.Name)) {
            throw "Each suite in '$Path' must define a non-empty Name."
        }

        if (-not ($suite.PSObject.Properties.Name -contains 'ConfigPath') -or [string]::IsNullOrWhiteSpace([string] $suite.ConfigPath)) {
            throw "Suite '$($suite.Name)' in '$Path' must define ConfigPath."
        }
    }
}

function Test-SuiteManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $SuiteConfig,

        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not ($SuiteConfig.PSObject.Properties.Name -contains 'Run') -or $null -eq $SuiteConfig.Run) {
        throw "Suite config '$Path' must define Run."
    }

    if (-not ($SuiteConfig.Run.PSObject.Properties.Name -contains 'Path')) {
        throw "Suite config '$Path' must define Run.Path."
    }

    if (@($SuiteConfig.Run.Path).Count -eq 0) {
        throw "Suite config '$Path' must include at least one Run.Path entry."
    }
}

function Write-TestRunSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Result,

        [Parameter(Mandatory)]
        [string] $RunLabel,

        [switch] $ShowPassedTests
    )

    Write-Host $RunLabel

    $allTests = @()
    if ($Result.PSObject.Properties.Name -contains 'Tests' -and $null -ne $Result.Tests) {
        $allTests = @($Result.Tests)
    }

    $nonPassing = @()
    if ($allTests.Count -gt 0) {
        $nonPassing = @($allTests | Where-Object {
            $_.Result -ne 'Passed' -and $_.Result -ne 'NotRun'
        })
    }

    $passing = @()
    if ($allTests.Count -gt 0) {
        $passing = @($allTests | Where-Object { $_.Result -eq 'Passed' })
    }

    if ($ShowPassedTests -and $passing.Count -gt 0) {
        foreach ($test in $passing) {
            Write-Host ("[+] {0}" -f $test.ExpandedPath)
        }
    }

    if ($nonPassing.Count -gt 0) {
        foreach ($test in $nonPassing) {
            $errorMessage = ''
            if ($test.ErrorRecord -and $test.ErrorRecord.Exception) {
                $errorMessage = $test.ErrorRecord.Exception.Message
            }

            if ([string]::IsNullOrWhiteSpace($errorMessage)) {
                Write-Host ("[-] {0} ({1})" -f $test.ExpandedPath, $test.Result)
            } else {
                Write-Host ("[-] {0} ({1})`n    {2}" -f $test.ExpandedPath, $test.Result, $errorMessage)
            }
        }
    } elseif (-not $ShowPassedTests) {
        Write-Host 'All tests passed. No non-passing tests to report.'
    }

    $durationSeconds = 0
    if ($Result.PSObject.Properties.Name -contains 'Duration' -and $null -ne $Result.Duration) {
        $durationSeconds = $Result.Duration.TotalSeconds
    }

    Write-Host ("Tests completed in {0:N2}s" -f $durationSeconds)
    Write-Host (
        "Tests Passed: {0}, Failed: {1}, Skipped: {2}, Inconclusive: {3}, NotRun: {4}" -f
        $Result.PassedCount,
        $Result.FailedCount,
        $Result.SkippedCount,
        $Result.InconclusiveCount,
        $Result.NotRunCount
    )
}

function Resolve-CoveragePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $SuiteConfig,

        [Parameter(Mandatory)]
        [string] $SuiteBaseDirectory,

        [Parameter(Mandatory)]
        [string] $SuiteConfigPath
    )

    $resolvedCoveragePaths = @()

    if (-not ($SuiteConfig.PSObject.Properties.Name -contains 'Coverage') -or $null -eq $SuiteConfig.Coverage) {
        throw "Coverage was requested but suite config '$SuiteConfigPath' does not define Coverage."
    }

    if (
        ($SuiteConfig.Coverage.PSObject.Properties.Name -contains 'Enabled') -and
        (-not [bool] $SuiteConfig.Coverage.Enabled)
    ) {
        throw "Coverage was requested but Coverage.Enabled is false in '$SuiteConfigPath'."
    }

    if (
        -not ($SuiteConfig.Coverage.PSObject.Properties.Name -contains 'Path') -or
        @($SuiteConfig.Coverage.Path).Count -eq 0
    ) {
        throw "Coverage was requested but Coverage.Path is missing or empty in '$SuiteConfigPath'."
    }

    foreach ($pathEntry in @($SuiteConfig.Coverage.Path)) {
        if ([System.IO.Path]::IsPathRooted([string] $pathEntry)) {
            $resolved = Resolve-Path -Path $pathEntry -ErrorAction SilentlyContinue
        } else {
            $resolved = Resolve-Path -Path (Join-Path $SuiteBaseDirectory $pathEntry) -ErrorAction SilentlyContinue
        }

        if ($null -eq $resolved) {
            throw "Coverage path was not found: $pathEntry (from $SuiteConfigPath)"
        }

        $resolvedCoveragePaths += $resolved.Path
    }

    return $resolvedCoveragePaths
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

    $resolvedOutputPath = $null
    if (
        ($SuiteConfig.Coverage.PSObject.Properties.Name -contains 'OutputPath') -and
        -not [string]::IsNullOrWhiteSpace([string] $SuiteConfig.Coverage.OutputPath)
    ) {
        $configuredOutputPath = [string] $SuiteConfig.Coverage.OutputPath
        if ([System.IO.Path]::IsPathRooted($configuredOutputPath)) {
            $resolvedOutputPath = $configuredOutputPath
        } else {
            $resolvedOutputPath = Join-Path -Path $RepositoryRoot -ChildPath $configuredOutputPath
        }
    } else {
        $defaultOutputDirectory = Join-Path -Path $RepositoryRoot -ChildPath 'artifacts/coverage'
        $resolvedOutputPath = Join-Path -Path $defaultOutputDirectory -ChildPath ("{0}.coverage.xml" -f $TestSuite)
    }

    $outputDirectory = Split-Path -Path $resolvedOutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path -Path $outputDirectory)) {
        [void] (New-Item -Path $outputDirectory -ItemType Directory -Force)
    }

    return $resolvedOutputPath
}

function Get-JaCoCoLineCoverageSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $CoverageOutputPath
    )

    if (-not (Test-Path -Path $CoverageOutputPath)) {
        return $null
    }

    try {
        [xml] $coverageReport = Get-Content -Path $CoverageOutputPath -Raw -ErrorAction Stop
        $lineCounter = @($coverageReport.report.counter | Where-Object { $_.type -eq 'LINE' } | Select-Object -First 1)
        if ($lineCounter.Count -eq 0) {
            return $null
        }

        $coveredLines = [int] $lineCounter[0].covered
        $missedLines = [int] $lineCounter[0].missed
        $totalLines = $coveredLines + $missedLines
        $coveragePercent = if ($totalLines -eq 0) { 0 } else { [math]::Round(($coveredLines / $totalLines) * 100, 2) }

        return [pscustomobject] @{
            CoveredLines = $coveredLines
            MissedLines = $missedLines
            TotalLines = $totalLines
            CoveragePercent = $coveragePercent
        }
    } catch {
        return $null
    }
}

$repoRoot = Get-RepositoryRoot -StartDirectories @((Get-Location).Path, $PSScriptRoot)
if ($null -eq $repoRoot) {
    Write-Error 'Could not locate repository root. Add a pester.json file with isRoot=true or ensure .git exists.'
    exit 2
}

$locationPushed = $false
Push-Location -Path $repoRoot
$locationPushed = $true

function Exit-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int] $Code
    )

    if ($script:locationPushed) {
        Pop-Location
        $script:locationPushed = $false
    }

    exit $Code
}

$rootConfigPath = Join-Path $repoRoot 'pester.json'
try {
    $rootConfig = Read-JsonFile -Path $rootConfigPath -Description 'Root test config'
    Test-RootManifest -RootConfig $rootConfig -Path $rootConfigPath
} catch {
    Write-Error $_
    Exit-Script -Code 2
}

if ($ListSuites) {
    Write-Host "Repository Root: $repoRoot"
    Write-Host 'Configured test suites:'
    foreach ($configuredSuite in @($rootConfig.TestSuites)) {
        Write-Host ("  {0} -> {1}" -f $configuredSuite.Name, $configuredSuite.ConfigPath)
    }
    Exit-Script -Code 0
}

$suite = @($rootConfig.TestSuites | Where-Object { $_.Name -eq $TestSuite } | Select-Object -First 1)
if ($suite.Count -eq 0) {
    $availableSuites = @($rootConfig.TestSuites | ForEach-Object { $_.Name }) -join ', '
    Write-Error "Unknown test suite '$TestSuite'. Available suites: $availableSuites"
    Exit-Script -Code 2
}

$suiteConfigPath = if ([System.IO.Path]::IsPathRooted($suite[0].ConfigPath)) {
    $suite[0].ConfigPath
} else {
    Join-Path $repoRoot $suite[0].ConfigPath
}

if (-not (Test-Path -Path $suiteConfigPath)) {
    Write-Error "Suite config was not found: $suiteConfigPath"
    Exit-Script -Code 2
}

try {
    $suiteConfig = Read-JsonFile -Path $suiteConfigPath -Description 'Suite config'
    Test-SuiteManifest -SuiteConfig $suiteConfig -Path $suiteConfigPath
} catch {
    Write-Error $_
    Exit-Script -Code 2
}

$suiteBaseDirectory = Split-Path -Path $suiteConfigPath -Parent
$resolvedPath = @()
foreach ($pathEntry in @($suiteConfig.Run.Path)) {
    if ([System.IO.Path]::IsPathRooted($pathEntry)) {
        $resolved = Resolve-Path -Path $pathEntry -ErrorAction SilentlyContinue
    } else {
        $resolved = Resolve-Path -Path (Join-Path $suiteBaseDirectory $pathEntry) -ErrorAction SilentlyContinue
    }

    if ($null -eq $resolved) {
        Write-Error "Suite path was not found: $pathEntry (from $suiteConfigPath)"
        Exit-Script -Code 2
    }

    $resolvedPath += $resolved.Path
}

Write-Host "Repository Root: $repoRoot"
Write-Host "Test Suite: $TestSuite"
Write-Host "Suite Config: $suiteConfigPath"
Write-Host 'Running tests in the following path(s):'
$resolvedPath | ForEach-Object { Write-Host "  $_" }

if ($ListTags) {
    $discoveryConfiguration = [PesterConfiguration]::Default
    $discoveryConfiguration.Run.Path = $resolvedPath
    $discoveryConfiguration.Run.PassThru = $true
    $discoveryConfiguration.Output.Verbosity = 'None'
    $discoveryConfiguration.Run.SkipRun = $true

    $discoveryResult = Invoke-Pester -Configuration $discoveryConfiguration

    $allTags = [System.Collections.Generic.List[string]]::new()
    $allBlocks = [System.Collections.Generic.List[object]]::new()

    function Add-DiscoveredBlock {
        param([object[]] $Blocks)

        foreach ($block in @($Blocks)) {
            if ($null -eq $block) { continue }

            $allBlocks.Add($block)
            if ($block.PSObject.Properties.Name -contains 'Blocks' -and $null -ne $block.Blocks) {
                Add-DiscoveredBlock -Blocks @($block.Blocks)
            }
        }
    }

    if ($null -ne $discoveryResult -and ($discoveryResult.PSObject.Properties.Name -contains 'Containers') -and $null -ne $discoveryResult.Containers) {
        foreach ($container in @($discoveryResult.Containers)) {
            if ($container.PSObject.Properties.Name -contains 'Blocks' -and $null -ne $container.Blocks) {
                Add-DiscoveredBlock -Blocks @($container.Blocks)
            }
        }
    }

    foreach ($discoveredBlock in $allBlocks) {
        if ($discoveredBlock.PSObject.Properties.Name -contains 'Tag' -and $null -ne $discoveredBlock.Tag) {
            foreach ($tagName in @($discoveredBlock.Tag)) {
                if (-not [string]::IsNullOrWhiteSpace([string] $tagName)) {
                    $allTags.Add([string] $tagName)
                }
            }
        }
    }

    $distinctTags = @($allTags | Sort-Object -Unique)
    if ($distinctTags.Count -eq 0) {
        Write-Host 'No tags were discovered for this suite.'
    } else {
        Write-Host 'Discovered tags:'
        foreach ($discoveredTag in $distinctTags) {
            Write-Host "  $discoveredTag"
        }
    }

    Exit-Script -Code 0
}

$previousDebugPreference = $DebugPreference
$previousGlobalDebugPreference = $global:DebugPreference

try {
    $effectiveDebugPreference = if ($DebugOutput) { 'Continue' } else { 'SilentlyContinue' }

    $DebugPreference = $effectiveDebugPreference
    $global:DebugPreference = $effectiveDebugPreference

    if ($DebugOutput) {
        Write-Debug 'Debug output enabled for this invocation.'
    } else {
        Write-Debug 'Debug output disabled for this invocation.'
    }

    $configuration = [PesterConfiguration]::Default
    $configuration.Run.Path = $resolvedPath
    $configuration.Run.PassThru = $true
    # Keep agent output compact unless detailed output is explicitly requested.
    if ($DetailedOutput) {
        $configuration.Output.Verbosity = if ($suiteConfig.Output.Verbosity) { [string] $suiteConfig.Output.Verbosity } else { 'Normal' }
    } else {
        $configuration.Output.Verbosity = 'None'
    }

    $effectiveIncludeTags = if ($null -ne $Tag -and $Tag.Count -gt 0) { $Tag } else { @($suiteConfig.Filter.Tag) }
    if ($effectiveIncludeTags.Count -gt 0) {
        $configuration.Filter.Tag = @($effectiveIncludeTags)
        Write-Host ("Include Tags: {0}" -f (@($effectiveIncludeTags) -join ', '))
    }

    $effectiveExcludeTags = if ($null -ne $ExcludeTag -and $ExcludeTag.Count -gt 0) { $ExcludeTag } else { @($suiteConfig.Filter.ExcludeTag) }
    if ($effectiveExcludeTags.Count -gt 0) {
        $configuration.Filter.ExcludeTag = @($effectiveExcludeTags)
        Write-Host ("Exclude Tags: {0}" -f (@($effectiveExcludeTags) -join ', '))
    }

    if ($CoverageMode -eq 'Full') {
        $resolvedCoveragePaths = Resolve-CoveragePath -SuiteConfig $suiteConfig -SuiteBaseDirectory $suiteBaseDirectory -SuiteConfigPath $suiteConfigPath
        $resolvedCoverageOutputPath = Resolve-CoverageOutputPath -SuiteConfig $suiteConfig -RepositoryRoot $repoRoot -TestSuite $TestSuite

        $configuration.CodeCoverage.Enabled = $true
        $configuration.CodeCoverage.Path = @($resolvedCoveragePaths)

        # Default to non-breakpoint coverage unless suite config opts in.
        $configuration.CodeCoverage.UseBreakpoints = $false

        if ($suiteConfig.Coverage.PSObject.Properties.Name -contains 'CoveragePercentTarget') {
            $configuration.CodeCoverage.CoveragePercentTarget = [double] $suiteConfig.Coverage.CoveragePercentTarget
        }

        if ($suiteConfig.Coverage.PSObject.Properties.Name -contains 'OutputFormat') {
            $configuration.CodeCoverage.OutputFormat = [string] $suiteConfig.Coverage.OutputFormat
        }

        $configuration.CodeCoverage.OutputPath = $resolvedCoverageOutputPath

        if ($suiteConfig.Coverage.PSObject.Properties.Name -contains 'ExcludeTests') {
            $configuration.CodeCoverage.ExcludeTests = [bool] $suiteConfig.Coverage.ExcludeTests
        }

        if ($suiteConfig.Coverage.PSObject.Properties.Name -contains 'RecursePaths') {
            $configuration.CodeCoverage.RecursePaths = [bool] $suiteConfig.Coverage.RecursePaths
        }

        if ($suiteConfig.Coverage.PSObject.Properties.Name -contains 'UseBreakpoints') {
            $configuration.CodeCoverage.UseBreakpoints = [bool] $suiteConfig.Coverage.UseBreakpoints
        }

        if ($suiteConfig.Coverage.PSObject.Properties.Name -contains 'SingleHitBreakpoints') {
            $configuration.CodeCoverage.SingleHitBreakpoints = [bool] $suiteConfig.Coverage.SingleHitBreakpoints
        }

        Write-Host 'Coverage Path(s):'
        $resolvedCoveragePaths | ForEach-Object { Write-Host "  $_" }

        Write-Host ("Coverage OutputPath: {0}" -f [string] $configuration.CodeCoverage.OutputPath.Value)

        Write-Host ("Coverage UseBreakpoints: {0}" -f [bool] $configuration.CodeCoverage.UseBreakpoints)

        if ($suiteConfig.Coverage.PSObject.Properties.Name -contains 'CoveragePercentTarget') {
            Write-Host ("Coverage Target: {0}%" -f [double] $suiteConfig.Coverage.CoveragePercentTarget)
        }

        $result = Invoke-Pester -Configuration $configuration
        Write-TestRunSummary -Result $result -RunLabel 'Coverage Validation Run:' -ShowPassedTests:$ShowPassed

        $coverageSummary = Get-JaCoCoLineCoverageSummary -CoverageOutputPath ([string] $configuration.CodeCoverage.OutputPath.Value)
        if ($null -ne $coverageSummary) {
            Write-Host (
                "Coverage Actual: {0}% ({1}/{2} lines covered, {3} missed)" -f
                $coverageSummary.CoveragePercent,
                $coverageSummary.CoveredLines,
                $coverageSummary.TotalLines,
                $coverageSummary.MissedLines
            )
        }
    } else {
        $result = Invoke-Pester -Configuration $configuration
        Write-TestRunSummary -Result $result -RunLabel 'Test Run:' -ShowPassedTests:$ShowPassed
    }
} finally {
    $DebugPreference = $previousDebugPreference
    $global:DebugPreference = $previousGlobalDebugPreference
}

if ($null -eq $result) {
    Write-Error 'Pester did not return a result object.'
    Exit-Script -Code 2
}

if ($PassThru) {
    $result
}

if ($result.FailedCount -gt 0) {
    Exit-Script -Code 1
}

Exit-Script -Code 0
