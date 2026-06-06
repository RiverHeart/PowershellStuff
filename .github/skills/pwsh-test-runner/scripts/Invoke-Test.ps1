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

.PARAMETER PassThru
    Returns the full Pester result object after printing the summary.

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -TestSuite Example

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -TestSuite Example -DebugOutput

.EXAMPLE
    ./.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1 -TestSuite Example -Tag DataGrid -PassThru

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
    [switch] $PassThru
)

function Test-IsInteractive {
    [CmdletBinding()]
    param()

    $isCiRun = ($env:CI -eq 'true') -or ($env:GITHUB_ACTIONS -eq 'true')

    if ($isCiRun) {
        return $false
    }

    try {
        return [Environment]::UserInteractive -and
            -not [System.Console]::IsOutputRedirected -and
            -not [System.Console]::IsInputRedirected
    } catch {
        Write-Debug "Could not determine console interactivity. Treating session as non-interactive. $_"
        return $false
    }
}

$isInteractive = Test-IsInteractive

$IsLatestPesterAvailable = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1
if (-not $IsLatestPesterAvailable) {
    if (-not $isInteractive) {
        Write-Error 'Pester module was not found and this is a non-interactive session (CI or redirected console). Install Pester before running tests.'
        exit 2
    }

    $Title = 'Pester v5 Required'
    $Message = 'Pester v5 or later is required to run tests. Would you like to install it?'
    $Options = [System.Management.Automation.Host.ChoiceDescription[]]@(
        [System.Management.Automation.Host.ChoiceDescription]::new('&Yes', 'Install Pester v5 from the PowerShell Gallery.'),
        [System.Management.Automation.Host.ChoiceDescription]::new('&No', 'Do not install Pester v5 and exit.')
    )

    $UserChoice = $Host.UI.PromptForChoice($Title, $Message, $Options, 0)
    if ($UserChoice -eq 0) {
        $InstallParams = @{
            Name = 'Pester'
            MinimumVersion = '5.0.0'
            Scope = 'CurrentUser'
            Force = $True
            ErrorAction = 'Stop;
        }
        if ($PSEdition -eq 'Desktop') {
            # Require because newer community-maintained versions have a different
            # digital certificate than the Microsoft one that signs the bundled Pester v3 module.
            $InstallParams.SkipPublisherCheck = $true
        }
        try {
            Install-Module @InstallParams
            Write-Host 'Pester v5 has been installed. Proceeding with test execution.'
        } catch {
            Write-Error "Failed to install Pester v5: $_"
            exit 2
        }
    } else {
        Write-Error 'Pester v5 installation declined by user. Exiting.'
        exit 2
    }
}

$IsUsingLatestPester = Get-Module Pester | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1
if (-not $IsUsingLatestPester -and $IsLatestPesterAvailable) {
    Import-Module -Name Pester -MinimumVersion '5.0.0' -Force
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

        $hasConfigPath = (
            ($suite.PSObject.Properties.Name -contains 'ConfigPath') -and
            -not [string]::IsNullOrWhiteSpace([string] $suite.ConfigPath)
        )

        $hasInlineSuiteConfig = (
            ($suite.PSObject.Properties.Name -contains 'Run') -and
            $null -ne $suite.Run
        )

        if ($hasConfigPath -and $hasInlineSuiteConfig) {
            throw "Suite '$($suite.Name)' in '$Path' cannot define both ConfigPath and inline Run configuration. Choose one style per suite."
        }

        if (-not $hasConfigPath -and -not $hasInlineSuiteConfig) {
            throw "Suite '$($suite.Name)' in '$Path' must define either ConfigPath or an inline suite Run configuration."
        }

        if ($hasInlineSuiteConfig) {
            Test-SuiteManifest -SuiteConfig $suite -Path "$Path (suite '$($suite.Name)')"
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

function Convert-SingleSuiteManifestToSuiteList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Config,

        [Parameter(Mandatory)]
        [string] $ConfigPath
    )

    Test-SuiteManifest -SuiteConfig $Config -Path $ConfigPath

    $suiteName = if (
        ($Config.PSObject.Properties.Name -contains 'TestSuite') -and
        -not [string]::IsNullOrWhiteSpace([string] $Config.TestSuite)
    ) {
        [string] $Config.TestSuite
    } else {
        'Default'
    }

    return @(
        [pscustomobject]@{
            Name       = $suiteName
            ConfigPath = $ConfigPath
        }
    )
}

$repoRoot = Get-RepositoryRoot -StartDirectories @((Get-Location).Path, $PSScriptRoot)
if ($null -eq $repoRoot) {
    Write-Error 'Could not locate repository root. Add a pester.json file with isRoot=true or ensure .git exists.'
    exit 2
}

Set-Location -Path $repoRoot

$rootConfigPath = Join-Path $repoRoot 'pester.json'

try {
    $rootConfig = Read-JsonFile -Path $rootConfigPath -Description 'Root test config'

    $hasRootLayout = (
        ($rootConfig.PSObject.Properties.Name -contains 'isRoot') -and
        [bool] $rootConfig.isRoot
    )

    if ($hasRootLayout) {
        Test-RootManifest -RootConfig $rootConfig -Path $rootConfigPath
        $configuredSuites = @($rootConfig.TestSuites)
    } else {
        # Alternative manifest style: allow a direct single-suite config at repo root.
        $configuredSuites = Convert-SingleSuiteManifestToSuiteList -Config $rootConfig -ConfigPath $rootConfigPath
    }
} catch {
    Write-Error $_
    exit 2
}

if ($ListSuites) {
    Write-Host "Repository Root: $repoRoot"
    Write-Host 'Configured test suites:'
    foreach ($configuredSuite in $configuredSuites) {
        $suiteSource = if (
            ($configuredSuite.PSObject.Properties.Name -contains 'ConfigPath') -and
            -not [string]::IsNullOrWhiteSpace([string] $configuredSuite.ConfigPath)
        ) {
            [string] $configuredSuite.ConfigPath
        } else {
            '(inline in root manifest)'
        }

        Write-Host ("  {0} -> {1}" -f $configuredSuite.Name, $suiteSource)
    }
    exit 0
}

$suite = @($configuredSuites | Where-Object { $_.Name -eq $TestSuite } | Select-Object -First 1)
if ($suite.Count -eq 0) {
    $availableSuites = @($configuredSuites | ForEach-Object { $_.Name }) -join ', '
    Write-Error "Unknown test suite '$TestSuite'. Available suites: $availableSuites"
    exit 2
}

$suiteConfigPath = $null
$suiteConfig = $null
$suiteBaseDirectory = $repoRoot

$hasSuiteConfigPath = (
    ($suite[0].PSObject.Properties.Name -contains 'ConfigPath') -and
    -not [string]::IsNullOrWhiteSpace([string] $suite[0].ConfigPath)
)

if ($hasSuiteConfigPath) {
    $suiteConfigPath = if ([System.IO.Path]::IsPathRooted($suite[0].ConfigPath)) {
        $suite[0].ConfigPath
    } else {
        Join-Path $repoRoot $suite[0].ConfigPath
    }

    if (-not (Test-Path -Path $suiteConfigPath)) {
        Write-Error "Suite config was not found: $suiteConfigPath"
        exit 2
    }

    try {
        $suiteConfig = Read-JsonFile -Path $suiteConfigPath -Description 'Suite config'
        Test-SuiteManifest -SuiteConfig $suiteConfig -Path $suiteConfigPath
    } catch {
        Write-Error $_
        exit 2
    }

    $suiteBaseDirectory = Split-Path -Path $suiteConfigPath -Parent
} else {
    $suiteConfigPath = $rootConfigPath
    $suiteConfig = $suite[0]

    try {
        Test-SuiteManifest -SuiteConfig $suiteConfig -Path "$rootConfigPath (suite '$($suite[0].Name)')"
    } catch {
        Write-Error $_
        exit 2
    }
}
$resolvedPath = @()
foreach ($pathEntry in @($suiteConfig.Run.Path)) {
    if ([System.IO.Path]::IsPathRooted($pathEntry)) {
        $resolved = Resolve-Path -Path $pathEntry -ErrorAction SilentlyContinue
    } else {
        $resolved = Resolve-Path -Path (Join-Path $suiteBaseDirectory $pathEntry) -ErrorAction SilentlyContinue
    }

    if ($null -eq $resolved) {
        Write-Error "Suite path was not found: $pathEntry (from $suiteConfigPath)"
        exit 2
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

    exit 0
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
    $configuration.Output.Verbosity = if ($suiteConfig.Output.Verbosity) { [string] $suiteConfig.Output.Verbosity } else { 'None' }

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

    $result = Invoke-Pester -Configuration $configuration
} finally {
    $DebugPreference = $previousDebugPreference
    $global:DebugPreference = $previousGlobalDebugPreference
}

if ($null -eq $result) {
    Write-Error 'Pester did not return a result object.'
    exit 2
}

$allTests = @()
if ($result.PSObject.Properties.Name -contains 'Tests' -and $null -ne $result.Tests) {
    $allTests = @($result.Tests)
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

if ($ShowPassed -and $passing.Count -gt 0) {
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
} elseif (-not $ShowPassed) {
    Write-Host 'All tests passed. No non-passing tests to report.'
}

$durationSeconds = 0
if ($result.PSObject.Properties.Name -contains 'Duration' -and $null -ne $result.Duration) {
    $durationSeconds = $result.Duration.TotalSeconds
}

Write-Host ("Tests completed in {0:N2}s" -f $durationSeconds)
Write-Host (
    "Tests Passed: {0}, Failed: {1}, Skipped: {2}, Inconclusive: {3}, NotRun: {4}" -f
    $result.PassedCount,
    $result.FailedCount,
    $result.SkippedCount,
    $result.InconclusiveCount,
    $result.NotRunCount
)

if ($PassThru) {
    $result
}

if ($result.FailedCount -gt 0) {
    exit 1
}

exit 0
