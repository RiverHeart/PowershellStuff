using namespace System
using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Host

<#
.SYNOPSIS
    Runs Pester tests with compact, failure-focused output using suite configuration.

.DESCRIPTION
    Invokes Pester using PassThru so results can be summarized without parsing noisy console output.
    By default, only failing or non-passing tests are printed, followed by stable summary lines:

    Tests completed in <seconds>s
    Tests Passed: X, Failed: Y, Skipped: Z, Inconclusive: A, NotRun: B

    Debug preference is scoped to this script invocation and restored in a finally block.
    Adds the repository's src\modules directory to PSModulePath before test discovery,
    restoring the original value afterward so module dependencies do not require a profile.

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

.PARAMETER Path
    Optional test paths to run instead of the paths configured by the suite. Relative paths
    are resolved from the directory containing the suite configuration. Each entry may also
    contain comma-separated paths, which is required when launching the script with
    `powershell.exe -File`, because that host does not parse `-Path a, b` as an array.

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

.PARAMETER DetailedOutput
    Enables detailed Pester console output for this invocation.

.PARAMETER ShowPassed
    Also prints passing tests in addition to non-passing tests.

.PARAMETER PassThru
    Returns the full Pester result object after printing the summary.

.PARAMETER ExitOnError
    Exits the hosting PowerShell process with code 2 when Pester reports a failed
    run: one or more failed tests, or a test container or block that failed during
    discovery or setup. Errors outside completed test results retain their normal
    error behavior.

.PARAMETER CoverageMode
    Runs Pester with the suite's Coverage configuration when set to Full.

.EXAMPLE
    Invoke-MDKTest -TestSuite Example

.EXAMPLE
    Invoke-MDKTest -TestSuite Example -DebugOutput

.EXAMPLE
    Invoke-MDKTest -Suite Example -Path Tests/Feature.tests.ps1 -DetailedOutput

.EXAMPLE
    Invoke-MDKTest -TestSuite Example -Tag DataGrid -PassThru

.EXAMPLE
    Invoke-MDKTest -ListSuites

.EXAMPLE
    Invoke-MDKTest -TestSuite Example -ListTags

.EXAMPLE
    Runs the Example suite under Windows PowerShell. The host used to launch this
    script selects the PowerShell runtime; Invoke-MDKTest restores that edition's
    CurrentUser module path before discovering Pester.

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command 'Invoke-MDKTest -Suite Example'

.EXAMPLE
    Run tests against multiple files.

    Invoke-MDKTest -Suite Example -Path Tests/A.tests.ps1, Tests/B.tests.ps1

.EXAMPLE
    Run tests and return exit code 2 when if failures occur.

    Invoke-MDKTest -Suite Example -ExitOnError
#>
function Invoke-MDKTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Run')]
        [Parameter(Mandatory, ParameterSetName = 'ListTags')]
        [ValidateNotNullOrEmpty()]
        [Alias('Suite')]
        [string] $TestSuite,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch] $ListSuites,

        [Parameter(Mandatory, ParameterSetName = 'ListTags')]
        [switch] $ListTags,

        [Parameter(ParameterSetName = 'Run')]
        [string[]] $Tag,

        [Parameter(ParameterSetName = 'Run')]
        [string[]] $ExcludeTag,

        [Parameter(ParameterSetName = 'Run')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [switch] $DebugOutput,
        [switch] $DetailedOutput,
        [switch] $ShowPassed,
        [switch] $PassThru,

        [Parameter(ParameterSetName = 'Run')]
        [switch] $ExitOnError,

        [Parameter(ParameterSetName = 'Run')]
        [ValidateSet('None', 'Full')]
        [string] $CoverageMode = 'None'
    )

    $OriginalPSModulePath = $env:PSModulePath
    $PushedLocation = $false

    try {
        Initialize-UserModulePath
        $isInteractive = Test-IsInteractive

        $IsLatestPesterAvailable = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1
        if (-not $IsLatestPesterAvailable) {
            if (-not $isInteractive) {
                Write-Error 'Pester module was not found and this is a non-interactive session (CI or redirected console). Install Pester before running tests.'
                return
            }

            $Title = 'Pester v5 Required'
            $Message = 'Pester v5 or later is required to run tests. Would you like to install it?'
            $Options = [ChoiceDescription[]]@(
                [ChoiceDescription]::new('&Yes', 'Install Pester v5 from the PowerShell Gallery.'),
                [ChoiceDescription]::new('&No', 'Do not install Pester v5 and exit.')
            )

            $UserChoice = $Host.UI.PromptForChoice($Title, $Message, $Options, 0)
            if ($UserChoice -eq 0) {
                $InstallParams = @{
                    Name = 'Pester'
                    MinimumVersion = '5.0.0'
                    Scope = 'CurrentUser'
                    Force = $True
                    ErrorAction = 'Stop'
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
                    return
                }
            } else {
                Write-Error 'Pester v5 installation declined by user. Exiting.'
                return
            }
        }

        $IsUsingLatestPester = Get-Module Pester | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1
        if (-not $IsUsingLatestPester -and $IsLatestPesterAvailable) {
            Import-Module -Name Pester -MinimumVersion '5.0.0' -Force
        }

        $RepoRoot = Get-RepositoryRoot -StartDirectories @((Get-Location).Path, $PSScriptRoot)
        if ($null -eq $RepoRoot) {
            Write-Error 'Could not locate repository root. Add a pester.json file with isRoot=true or ensure .git exists.'
            return
        }

        Push-Location -Path $RepoRoot -StackName 'DTTest'
        $PushedLocation = $true

        $RepositoryModulePath = Join-Path $RepoRoot 'src\modules'
        if ((Test-Path -LiteralPath $RepositoryModulePath -PathType Container) -and
            $RepositoryModulePath -notin ($env:PSModulePath -split [Path]::PathSeparator)
        ) {
            $env:PSModulePath = $RepositoryModulePath + [Path]::PathSeparator + $env:PSModulePath
        }

        $LoadedPester = Get-Module -Name Pester |
            Where-Object { $_.Version.Major -ge 5 } |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1

        Write-Host ("PowerShell: {0} ({1})" -f $PSVersionTable.PSVersion, $PSEdition)
        Write-Host ("Pester: {0}" -f $LoadedPester.Version)

        $RootConfigPath = Join-Path $RepoRoot 'pester.json'

        try {
            $RootConfig = Read-JsonFile -Path $RootConfigPath -Description 'Root test config'

            $HasRootLayout = (
                ($RootConfig.PSObject.Properties.Name -contains 'isRoot') -and
                [bool] $RootConfig.isRoot
            )

            if ($HasRootLayout) {
                Test-RootManifest -RootConfig $RootConfig -Path $RootConfigPath
                $ConfiguredSuites = @($RootConfig.TestSuites)
            } else {
                # Alternative manifest style: allow a direct single-suite config at repo root.
                $ConfiguredSuites = Convert-SingleSuiteManifestToSuiteList `
                    -Config $RootConfig `
                    -ConfigPath $RootConfigPath
            }
        } catch {
            Write-Error $_
            return
        }

        if ($ListSuites) {
            Write-Host "Repository Root: $RepoRoot"
            Write-Host 'Configured test suites:'
            foreach ($ConfiguredSuite in $ConfiguredSuites) {
                $SuiteSource = if (
                    ($ConfiguredSuite.PSObject.Properties.Name -contains 'ConfigPath') -and
                    -not [string]::IsNullOrWhiteSpace([string] $ConfiguredSuite.ConfigPath)
                ) {
                    [string] $ConfiguredSuite.ConfigPath
                } else {
                    '(inline in root manifest)'
                }

                Write-Host ("  {0} -> {1}" -f $ConfiguredSuite.Name, $SuiteSource)
            }
            return
        }

        $Suite = @($ConfiguredSuites |
            Where-Object { $_.Name -eq $TestSuite } |
            Select-Object -First 1)

        if ($Suite.Count -eq 0) {
            $AvailableSuites = @($ConfiguredSuites | ForEach-Object { $_.Name }) -join ', '
            Write-Error "Unknown test suite '$TestSuite'. Available suites: $AvailableSuites"
            return
        }

        $SuiteConfigPath = $null
        $SuiteConfig = $null
        $SuiteBaseDirectory = $RepoRoot

        $HasSuiteConfigPath = (
            ($Suite[0].PSObject.Properties.Name -contains 'ConfigPath') -and
            -not [string]::IsNullOrWhiteSpace([string] $Suite[0].ConfigPath)
        )

        if ($HasSuiteConfigPath) {
            $SuiteConfigPath = if ([Path]::IsPathRooted($Suite[0].ConfigPath)) {
                $Suite[0].ConfigPath
            } else {
                Join-Path $RepoRoot $Suite[0].ConfigPath
            }

            if (-not (Test-Path -Path $SuiteConfigPath)) {
                Write-Error "Suite config was not found: $SuiteConfigPath"
                return
            }

            try {
                $SuiteConfig = Read-JsonFile -Path $SuiteConfigPath -Description 'Suite config'
                Test-SuiteManifest -SuiteConfig $SuiteConfig -Path $SuiteConfigPath
            } catch {
                Write-Error $_
                return
            }

            $SuiteBaseDirectory = Split-Path -Path $SuiteConfigPath -Parent
        } else {
            $SuiteConfigPath = $RootConfigPath
            $SuiteConfig = $Suite[0]

            try {
                Test-SuiteManifest `
                    -SuiteConfig $SuiteConfig `
                    -Path "$RootConfigPath (suite '$($Suite[0].Name)')"
            } catch {
                Write-Error $_
                return
            }
        }
        # Under `powershell.exe -File`, `-Path a,b` arrives as the single string 'a,b'.
        $RequestedPath = if ($null -ne $Path -and $Path.Count -gt 0) {
            @($Path -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        } else {
            @($SuiteConfig.Run.Path)
        }

        $ResolvedPath = @()
        foreach ($PathEntry in $RequestedPath) {
            if ([Path]::IsPathRooted($PathEntry)) {
                $Resolved = Resolve-Path -Path $PathEntry -ErrorAction SilentlyContinue
            } else {
                $Resolved = Resolve-Path -Path (Join-Path $SuiteBaseDirectory $PathEntry) -ErrorAction SilentlyContinue
            }

            if ($null -eq $Resolved) {
                Write-Error "Suite path was not found: $PathEntry (from $SuiteConfigPath)"
                return
            }

            $ResolvedPath += $Resolved.Path
        }

        Write-Host "Repository Root: $RepoRoot"
        Write-Host "Test Suite: $TestSuite"
        Write-Host "Suite Config: $SuiteConfigPath"
        Write-Host 'Running tests in the following path(s):'
        $ResolvedPath | ForEach-Object { Write-Host "  $_" }

        if ($ListTags) {
            $DiscoveryConfiguration = [PesterConfiguration]::Default
            $DiscoveryConfiguration.Run.Path = $ResolvedPath
            $DiscoveryConfiguration.Run.PassThru = $true
            $DiscoveryConfiguration.Output.Verbosity = 'None'
            $DiscoveryConfiguration.Run.SkipRun = $true

            $DiscoveryResult = Invoke-Pester -Configuration $DiscoveryConfiguration

            $AllTags = [List[string]]::new()
            $AllBlocks = [List[object]]::new()

            function Add-DiscoveredBlock {
                param([object[]] $Blocks)

                foreach ($block in @($Blocks)) {
                    if ($null -eq $block) { continue }

                    $AllBlocks.Add($block)
                    if ($block.PSObject.Properties.Name -contains 'Blocks' -and
                        $null -ne $block.Blocks
                    ) {
                        Add-DiscoveredBlock -Blocks @($block.Blocks)
                    }
                }
            }

            if ($null -ne $DiscoveryResult -and
                ($DiscoveryResult.PSObject.Properties.Name -contains 'Containers') -and
                $null -ne $DiscoveryResult.Containers
            ) {
                foreach ($Container in @($DiscoveryResult.Containers)) {
                    if ($Container.PSObject.Properties.Name -contains 'Blocks' -and
                        $null -ne $Container.Blocks
                    ) {
                        Add-DiscoveredBlock -Blocks @($Container.Blocks)
                    }
                }
            }

            foreach ($DiscoveredBlock in $AllBlocks) {
                if ($DiscoveredBlock.PSObject.Properties.Name -contains 'Tag' -and
                    $null -ne $DiscoveredBlock.Tag
                ) {
                    foreach ($TagName in @($DiscoveredBlock.Tag)) {
                        if (-not [string]::IsNullOrWhiteSpace([string] $TagName)) {
                            $AllTags.Add([string] $TagName)
                        }
                    }
                }
            }

            $DistinctTags = @($AllTags | Sort-Object -Unique)
            if ($DistinctTags.Count -eq 0) {
                Write-Host 'No tags were discovered for this suite.'
            } else {
                Write-Host 'Discovered tags:'
                foreach ($DiscoveredTag in $DistinctTags) {
                    Write-Host "  $DiscoveredTag"
                }
            }

            return
        }

        $PreviousDebugPreference = $DebugPreference
        $PreviousGlobalDebugPreference = $global:DebugPreference

        try {
            $effectiveDebugPreference = if ($DebugOutput) { 'Continue' } else { 'SilentlyContinue' }

            $DebugPreference = $effectiveDebugPreference
            $global:DebugPreference = $effectiveDebugPreference

            if ($DebugOutput) {
                Write-Debug 'Debug output enabled for this invocation.'
            } else {
                Write-Debug 'Debug output disabled for this invocation.'
            }

            $Configuration = [PesterConfiguration]::Default
            $Configuration.Run.Path = $ResolvedPath
            $Configuration.Run.PassThru = $true
            $Configuration.Output.Verbosity = if ($DetailedOutput) {
                'Detailed'
            } elseif ($SuiteConfig.Output.Verbosity) {
                [string] $SuiteConfig.Output.Verbosity
            } else {
                'None'
            }

            $EffectiveIncludeTags = if ($null -ne $Tag -and $Tag.Count -gt 0) { $Tag } else { @($SuiteConfig.Filter.Tag) }
            if ($EffectiveIncludeTags.Count -gt 0) {
                $Configuration.Filter.Tag = @($EffectiveIncludeTags)
                Write-Host ("Include Tags: {0}" -f (@($EffectiveIncludeTags) -join ', '))
            }

            $EffectiveExcludeTags = if ($null -ne $ExcludeTag -and $ExcludeTag.Count -gt 0) { $ExcludeTag } else { @($SuiteConfig.Filter.ExcludeTag) }
            if ($EffectiveExcludeTags.Count -gt 0) {
                $Configuration.Filter.ExcludeTag = @($EffectiveExcludeTags)
                Write-Host ("Exclude Tags: {0}" -f (@($EffectiveExcludeTags) -join ', '))
            }

            if ($CoverageMode -eq 'Full') {
                if (
                    -not ($SuiteConfig.PSObject.Properties.Name -contains 'Coverage') -or
                    $null -eq $SuiteConfig.Coverage
                ) {
                    throw "Suite '$TestSuite' does not define Coverage configuration."
                }

                $Configuration.CodeCoverage.Enabled = $true
                $CoveragePath = @($SuiteConfig.Coverage.Path | ForEach-Object {
                    if ([Path]::IsPathRooted($_)) {
                        $_
                    } else {
                        Join-Path -Path $SuiteBaseDirectory -ChildPath $_
                    }
                })
                if ($CoveragePath.Count -eq 0) {
                    throw "Suite '$TestSuite' must define at least one Coverage.Path entry."
                }

                $Configuration.CodeCoverage.Path = $CoveragePath
                $Configuration.CodeCoverage.OutputPath = Resolve-CoverageOutputPath `
                    -SuiteConfig $SuiteConfig `
                    -RepositoryRoot $RepoRoot `
                    -TestSuite $TestSuite

                $Configuration.CodeCoverage.UseBreakpoints = $false
                $CoverageOptions = @(
                    'CoveragePercentTarget'
                    'ExcludeTests'
                    'OutputEncoding'
                    'OutputFormat'
                    'RecursePaths'
                    'SingleHitBreakpoints'
                    'UseBreakpoints'
                )
                foreach ($CoverageOption in $CoverageOptions) {
                    if (
                        $SuiteConfig.Coverage.PSObject.Properties.Name -contains $CoverageOption
                    ) {
                        $Configuration.CodeCoverage.$CoverageOption =
                            $SuiteConfig.Coverage.$CoverageOption
                    }
                }

                $CoverageOutputDirectory = Split-Path `
                    -Path $Configuration.CodeCoverage.OutputPath.Value `
                    -Parent
                New-Item -Path $CoverageOutputDirectory `
                    -ItemType Directory `
                    -Force `
                    -ErrorAction Stop |
                    Out-Null
            }

            $Result = Invoke-Pester -Configuration $Configuration
        } finally {
            $DebugPreference = $PreviousDebugPreference
            $global:DebugPreference = $PreviousGlobalDebugPreference
        }

        if ($null -eq $Result) {
            Write-Error 'Pester did not return a result object.'
            return
        }

        $AllTests = @()
        if ($Result.PSObject.Properties.Name -contains 'Tests' -and $null -ne $Result.Tests) {
            $AllTests = @($Result.Tests)
        }

        $NonPassing = @()
        if ($AllTests.Count -gt 0) {
            $NonPassing = @($AllTests | Where-Object {
                $_.Result -ne 'Passed' -and $_.Result -ne 'NotRun'
            })
        }

        $Passing = @()
        if ($AllTests.Count -gt 0) {
            $Passing = @($AllTests | Where-Object { $_.Result -eq 'Passed' })
        }

        if ($ShowPassed -and $Passing.Count -gt 0) {
            foreach ($Test in $Passing) {
                Write-Host ("[+] {0}" -f $Test.ExpandedPath)
            }
        }

        # Discovery and setup failures never reach FailedCount, so they are reported separately.
        $FailedContainers = @()
        if ($Result.PSObject.Properties.Name -contains 'Containers' -and
            $null -ne $Result.Containers
        ) {
            $FailedContainers = @($Result.Containers | Where-Object {
                $_.Result -eq 'Failed' -and @($_.ErrorRecord).Count -gt 0
            })
        }

        $FailedBlocks = @()
        if ($Result.PSObject.Properties.Name -contains 'FailedBlocks' -and
            $null -ne $Result.FailedBlocks
        ) {
            $FailedBlocks = @($Result.FailedBlocks | Where-Object { @($_.ErrorRecord).Count -gt 0 })
        }

        <#
        .SYNOPSIS
            Returns a one-line summary of the first error record, preferring parse error details.
        #>
        function Get-FirstErrorLine {
            param([object[]] $ErrorRecords)

            foreach ($Record in @($ErrorRecords)) {
                $Exception = $Record.Exception

                # Parse errors put the location first and the message several lines down.
                if ($Exception -is [ParseException] -and @($Exception.Errors).Count -gt 0) {
                    $ParseError = @($Exception.Errors)[0]
                    return ('{0}:{1}: {2}' -f $ParseError.Extent.File, $ParseError.Extent.StartLineNumber, $ParseError.Message)
                }

                $Message = if ($Exception) { $Exception.Message } else { "$Record" }
                if (-not [string]::IsNullOrWhiteSpace($Message)) {
                    return ($Message -split "`r?`n")[0]
                }
            }

            return ''
        }

        foreach ($Container in $FailedContainers) {
            Write-Host ("[-] Container failed: {0}`n    {1}" -f $Container.Item, (Get-FirstErrorLine $Container.ErrorRecord))
        }

        foreach ($Block in $FailedBlocks) {
            Write-Host ("[-] Block failed: {0}`n    {1}" -f $Block.ExpandedPath, (Get-FirstErrorLine $Block.ErrorRecord))
        }

        if ($NonPassing.Count -gt 0) {
            foreach ($Test in $NonPassing) {
                $ErrorMessage = Get-FirstErrorLine $Test.ErrorRecord
                if ([string]::IsNullOrWhiteSpace($ErrorMessage) -and $Test.Block) {
                    $ErrorMessage = Get-FirstErrorLine $Test.Block.ErrorRecord
                }

                if ([string]::IsNullOrWhiteSpace($ErrorMessage)) {
                    Write-Host ("[-] {0} ({1})" -f $Test.ExpandedPath, $Test.Result)
                } else {
                    Write-Host ("[-] {0} ({1})`n    {2}" -f $Test.ExpandedPath, $Test.Result, $ErrorMessage)
                }
            }
        } elseif ($FailedContainers.Count -eq 0 -and $FailedBlocks.Count -eq 0 -and -not $ShowPassed) {
            Write-Host 'All tests passed. No non-passing tests to report.'
        }

        $DurationSeconds = 0
        if ($Result.PSObject.Properties.Name -contains 'Duration' -and
            $null -ne $Result.Duration
        ) {
            $DurationSeconds = $Result.Duration.TotalSeconds
        }

        Write-Host ("Tests completed in {0:N2}s" -f $DurationSeconds)
        Write-Host (
            "Tests Passed: {0}, Failed: {1}, Skipped: {2}, Inconclusive: {3}, NotRun: {4}" -f
            $Result.PassedCount,
            $Result.FailedCount,
            $Result.SkippedCount,
            $Result.InconclusiveCount,
            $Result.NotRunCount
        )

        if ($FailedContainers.Count -gt 0 -or $FailedBlocks.Count -gt 0) {
            Write-Host (
                "Failed Containers: {0}, Failed Blocks: {1}" -f
                $FailedContainers.Count, $FailedBlocks.Count
            )
        }

        if ($PassThru) {
            $Result
        }

        # Pester's overall Result also covers failures that do not reach FailedCount.
        $RunFailed = $Result.FailedCount -gt 0 -or
            $FailedContainers.Count -gt 0 -or
            $FailedBlocks.Count -gt 0 -or
            $Result.Result -eq 'Failed'

        if ($RunFailed) {
            if ($ExitOnError) {
                exit 2
            }

            Write-Error 'One or more tests failed.'
            return
        }

        return
    } finally {
        if ($PushedLocation) {
            Pop-Location -StackName 'DTTest'
        }
        $env:PSModulePath = $OriginalPSModulePath
    }
}
