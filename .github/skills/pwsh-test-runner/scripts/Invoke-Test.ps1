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

$script:LocationPushed = $false

function Restore-OriginalLocation {
    [CmdletBinding()]
    param()

    if ($script:LocationPushed) {
        Pop-Location -ErrorAction SilentlyContinue
        $script:LocationPushed = $false
    }
}

function Test-IsInteractive {
    [CmdletBinding()]
    [OutputType([bool])]
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

try {
    $isInteractive = Test-IsInteractive

    $IsLatestPesterAvailable = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1
    if (-not $IsLatestPesterAvailable) {
        if (-not $isInteractive) {
            Write-Error 'Pester module was not found and this is a non-interactive session (CI or redirected console). Install Pester before running tests.'
            return
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

function Get-RepositoryRoot {
    [CmdletBinding()]
    [OutputType([string])]
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
                $RootConfigPath = Join-Path $current 'pester.json'
                if (Test-Path -Path $RootConfigPath) {
                    try {
                        $RootConfig = Get-Content -Path $RootConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
                        if ($RootConfig.PSObject.Properties.Name -contains 'isRoot' -and [bool] $RootConfig.isRoot) {
                            return $current
                        }
                    } catch {
                        Write-Debug "Ignoring invalid root config at '$RootConfigPath': $_"
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

    $Suites = @($RootConfig.TestSuites)
    if ($Suites.Count -eq 0) {
        throw "Root config '$Path' must define at least one suite in TestSuites."
    }

    foreach ($Suite in $Suites) {
        if (-not ($Suite.PSObject.Properties.Name -contains 'Name') -or [string]::IsNullOrWhiteSpace([string] $Suite.Name)) {
            throw "Each suite in '$Path' must define a non-empty Name."
        }

        $hasConfigPath = (
            ($Suite.PSObject.Properties.Name -contains 'ConfigPath') -and
            -not [string]::IsNullOrWhiteSpace([string] $Suite.ConfigPath)
        )

        $hasInlineSuiteConfig = (
            ($Suite.PSObject.Properties.Name -contains 'Run') -and
            $null -ne $Suite.Run
        )

        if ($hasConfigPath -and $hasInlineSuiteConfig) {
            throw "Suite '$($Suite.Name)' in '$Path' cannot define both ConfigPath and inline Run configuration. Choose one style per suite."
        }

        if (-not $hasConfigPath -and -not $hasInlineSuiteConfig) {
            throw "Suite '$($Suite.Name)' in '$Path' must define either ConfigPath or an inline suite Run configuration."
        }

        if ($hasInlineSuiteConfig) {
            Test-SuiteManifest -SuiteConfig $Suite -Path "$Path (suite '$($Suite.Name)')"
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
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object] $Config,

        [Parameter(Mandatory)]
        [string] $ConfigPath
    )

    Test-SuiteManifest -SuiteConfig $Config -Path $ConfigPath

    $SuiteName = if (
        ($Config.PSObject.Properties.Name -contains 'TestSuite') -and
        -not [string]::IsNullOrWhiteSpace([string] $Config.TestSuite)
    ) {
        [string] $Config.TestSuite
    } else {
        'Default'
    }

    return @(
        [pscustomobject]@{
            Name       = $SuiteName
            ConfigPath = $ConfigPath
        }
    )
}

    $RepoRoot = Get-RepositoryRoot -StartDirectories @((Get-Location).Path, $PSScriptRoot)
    if ($null -eq $RepoRoot) {
        Write-Error 'Could not locate repository root. Add a pester.json file with isRoot=true or ensure .git exists.'
        return
    }

    Push-Location -Path $RepoRoot
    $script:LocationPushed = $true

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
            $ConfiguredSuites = Convert-SingleSuiteManifestToSuiteList -Config $RootConfig -ConfigPath $RootConfigPath
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

    $Suite = @($ConfiguredSuites | Where-Object { $_.Name -eq $TestSuite } | Select-Object -First 1)
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
        $SuiteConfigPath = if ([System.IO.Path]::IsPathRooted($Suite[0].ConfigPath)) {
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
            Test-SuiteManifest -SuiteConfig $SuiteConfig -Path "$RootConfigPath (suite '$($Suite[0].Name)')"
        } catch {
            Write-Error $_
            return
        }
    }
    $ResolvedPath = @()
    foreach ($PathEntry in @($SuiteConfig.Run.Path)) {
        if ([System.IO.Path]::IsPathRooted($PathEntry)) {
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

        $AllTags = [System.Collections.Generic.List[string]]::new()
        $AllBlocks = [System.Collections.Generic.List[object]]::new()

        function Add-DiscoveredBlock {
            param([object[]] $Blocks)

            foreach ($block in @($Blocks)) {
                if ($null -eq $block) { continue }

                $AllBlocks.Add($block)
                if ($block.PSObject.Properties.Name -contains 'Blocks' -and $null -ne $block.Blocks) {
                    Add-DiscoveredBlock -Blocks @($block.Blocks)
                }
            }
        }

        if ($null -ne $DiscoveryResult -and ($DiscoveryResult.PSObject.Properties.Name -contains 'Containers') -and $null -ne $DiscoveryResult.Containers) {
            foreach ($Container in @($DiscoveryResult.Containers)) {
                if ($Container.PSObject.Properties.Name -contains 'Blocks' -and $null -ne $Container.Blocks) {
                    Add-DiscoveredBlock -Blocks @($Container.Blocks)
                }
            }
        }

        foreach ($DiscoveredBlock in $AllBlocks) {
            if ($DiscoveredBlock.PSObject.Properties.Name -contains 'Tag' -and $null -ne $DiscoveredBlock.Tag) {
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
        $Configuration.Output.Verbosity = if ($SuiteConfig.Output.Verbosity) { [string] $SuiteConfig.Output.Verbosity } else { 'None' }

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

    if ($NonPassing.Count -gt 0) {
        foreach ($Test in $NonPassing) {
            $ErrorMessage = ''
            if ($Test.ErrorRecord -and $Test.ErrorRecord.Exception) {
                $ErrorMessage = $Test.ErrorRecord.Exception.Message
            }

            if ([string]::IsNullOrWhiteSpace($ErrorMessage)) {
                Write-Host ("[-] {0} ({1})" -f $Test.ExpandedPath, $Test.Result)
            } else {
                Write-Host ("[-] {0} ({1})`n    {2}" -f $Test.ExpandedPath, $Test.Result, $ErrorMessage)
            }
        }
    } elseif (-not $ShowPassed) {
        Write-Host 'All tests passed. No non-passing tests to report.'
    }

    $DurationSeconds = 0
    if ($Result.PSObject.Properties.Name -contains 'Duration' -and $null -ne $Result.Duration) {
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

    if ($PassThru) {
        $Result
    }

    if ($Result.FailedCount -gt 0) {
        Write-Error 'One or more tests failed.'
        return
    }

    return
} finally {
    Restore-OriginalLocation
}
