<#
.SYNOPSIS
    Runs WPF Pester tests with compact, failure-focused output.

.DESCRIPTION
    Invokes Pester using PassThru so results can be summarized without parsing noisy console output.
    By default, only failing/non-passing tests are printed, followed by stable summary lines:

    Tests completed in <seconds>s
    Tests Passed: X, Failed: Y, Skipped: Z, Inconclusive: A, NotRun: B

    Debug preference is scoped to this script invocation and restored in a finally block.

.NOTES
    This is geared towards AI agent use reduce token consumption and provide a clear summary of test results
    without them needing to parse it.

.PARAMETER Path
    One or more test paths to run. Defaults to src/modules/WPF/Tests.

.PARAMETER DebugOutput
    Enables debug output only for this invocation.

.PARAMETER ShowPassed
    Also prints passing tests in addition to non-passing tests.

.PARAMETER PassThru
    Returns the full Pester result object after printing the summary.

.EXAMPLE
    ./Scripts/Invoke-WPFTestSummary.ps1

.EXAMPLE
    ./Scripts/Invoke-WPFTestSummary.ps1 -DebugOutput

.EXAMPLE
    ./Scripts/Invoke-WPFTestSummary.ps1 -Path ./Tests/TimedEvent.Tests.ps1 -PassThru
#>
[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string[]] $Path = @("$PSScriptRoot/../Tests"),

    [switch] $DebugOutput,
    [switch] $ShowPassed,
    [switch] $PassThru
)

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

    if (-not (Get-Module -Name Pester)) {
        $pesterModule = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
        if ($null -eq $pesterModule) {
            throw 'Pester module was not found. Install Pester to run tests.'
        }

        Import-Module -Name $pesterModule.Path -ErrorAction Stop
    }

    $configuration = [PesterConfiguration]::Default
    $configuration.Run.Path = $Path
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'None'

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
    $nonPassing = @($allTests | Where-Object { $_.Result -ne 'Passed' })
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
