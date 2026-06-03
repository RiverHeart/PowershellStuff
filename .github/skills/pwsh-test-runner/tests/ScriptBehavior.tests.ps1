Describe 'test-runner skill scripts' {
    BeforeAll {
        $script:InvokeTestCoverageSource = Join-Path -Path $PSScriptRoot -ChildPath '../scripts/Invoke-TestCoverage.ps1'
        $script:InvokeNewCodeGateSource = Join-Path -Path $PSScriptRoot -ChildPath '../scripts/Invoke-NewCodeGate.ps1'

        function script:Invoke-ExternalPwshScript {
            param(
                [Parameter(Mandatory)]
                [string] $WorkingDirectory,

                [Parameter(Mandatory)]
                [string] $ScriptPath,

                [string[]] $Arguments = @()
            )

            Push-Location -Path $WorkingDirectory
            try {
                $output = @(& pwsh -NoProfile -NonInteractive -File $ScriptPath @Arguments 2>&1)
                $exitCode = $LASTEXITCODE
            } finally {
                Pop-Location
            }

            return [pscustomobject] @{
                ExitCode = $exitCode
                Output = @($output)
                Text = ($output -join [Environment]::NewLine)
            }
        }

        function script:New-TestCoverageSandbox {
            param(
                [Parameter(Mandatory)]
                [string] $RootPath,

                [string] $CoverageMode = $null,

                [string] $CoverageOutputPath = 'artifacts/coverage/Fake.coverage.xml'
            )

            $scriptsPath = Join-Path -Path $RootPath -ChildPath 'scripts'
            New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null

            Copy-Item -Path $script:InvokeTestCoverageSource -Destination (Join-Path -Path $scriptsPath -ChildPath 'Invoke-TestCoverage.ps1') -Force

            @"
{
  "isRoot": true,
  "TestSuites": [
    {
      "Name": "Fake",
      "ConfigPath": "suite.json"
    }
  ]
}
"@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'pester.json') -NoNewline

            $modeLine = if ([string]::IsNullOrWhiteSpace($CoverageMode)) { '' } else { "`n    `"Mode`": `"$CoverageMode`"," }
            @"
{
  "TestSuite": "Fake",
  "Run": {
    "Path": [
      "."
    ]
  },
  "Coverage": {${modeLine}
    "OutputPath": "$CoverageOutputPath"
  }
}
"@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'suite.json') -NoNewline

            @"
param(
    [string]`$TestSuite,
    [string]`$CoverageMode,
    [string[]]`$Tag,
    [string[]]`$ExcludeTag,
    [switch]`$DebugOutput,
    [switch]`$DetailedOutput,
    [switch]`$ShowPassed
)

`$data = [pscustomobject]@{
    TestSuite = `$TestSuite
    CoverageMode = `$CoverageMode
    Tag = @(`$Tag)
    ExcludeTag = @(`$ExcludeTag)
    DebugOutput = [bool]`$DebugOutput
    DetailedOutput = [bool]`$DetailedOutput
    ShowPassed = [bool]`$ShowPassed
}

`$data | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path -Path `$PSScriptRoot -ChildPath 'invoke-test.params.json') -NoNewline
exit 0
"@ | Set-Content -Path (Join-Path -Path $scriptsPath -ChildPath 'Invoke-Test.ps1') -NoNewline

            @"
param(
    [string]`$BaseRef,
    [string]`$CoveragePath,
    [double]`$MinimumCoveragePercent,
    [string[]]`$IncludePattern,
    [string[]]`$ExcludePathRegex
)

`$data = [pscustomobject]@{
    BaseRef = `$BaseRef
    CoveragePath = `$CoveragePath
    MinimumCoveragePercent = `$MinimumCoveragePercent
    IncludePattern = @(`$IncludePattern)
    ExcludePathRegex = @(`$ExcludePathRegex)
}

`$data | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path -Path `$PSScriptRoot -ChildPath 'invoke-gate.params.json') -NoNewline
exit 0
"@ | Set-Content -Path (Join-Path -Path $scriptsPath -ChildPath 'Invoke-NewCodeGate.ps1') -NoNewline

            return [pscustomobject] @{
                RootPath = $RootPath
                EntryScriptPath = (Join-Path -Path $scriptsPath -ChildPath 'Invoke-TestCoverage.ps1')
                InvokeTestParamsPath = (Join-Path -Path $scriptsPath -ChildPath 'invoke-test.params.json')
                InvokeGateParamsPath = (Join-Path -Path $scriptsPath -ChildPath 'invoke-gate.params.json')
            }
        }

        function script:New-NewCodeGateSandbox {
            param(
                [Parameter(Mandatory)]
                [string] $RootPath,

                [Parameter(Mandatory)]
                [string] $LineCoverageValue
            )

            New-Item -Path $RootPath -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path -Path $RootPath -ChildPath '.git') -ItemType Directory -Force | Out-Null

            Copy-Item -Path $script:InvokeNewCodeGateSource -Destination (Join-Path -Path $RootPath -ChildPath 'Invoke-NewCodeGate.ps1') -Force

            @"
<?xml version="1.0" encoding="UTF-8"?>
<report name="Pester">
  <package name="src">
    <sourcefile name="sample.ps1">
      <line nr="2" mi="0" ci="$LineCoverageValue" mb="0" cb="0" />
    </sourcefile>
  </package>
</report>
"@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'coverage.xml') -NoNewline

                        @"
@echo off
setlocal EnableDelayedExpansion

if "%3"=="rev-parse" exit /b 0
if "%3"=="diff" (
    echo +++ b/src/sample.ps1
    echo @@ -0,0 +2 @@
    exit /b 0
)

exit /b 0
"@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'git.cmd') -NoNewline

            return [pscustomobject] @{
                RootPath = $RootPath
                EntryScriptPath = (Join-Path -Path $RootPath -ChildPath 'Invoke-NewCodeGate.ps1')
                CoveragePath = (Join-Path -Path $RootPath -ChildPath 'coverage.xml')
            }
        }
    }

    Context 'Invoke-TestCoverage orchestration' {
        It 'runs Invoke-Test with CoverageMode Full and skips gate when effective mode is Full' {
            $sandbox = New-TestCoverageSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'coverage-full')

            $run = Invoke-ExternalPwshScript `
                -WorkingDirectory $sandbox.RootPath `
                -ScriptPath $sandbox.EntryScriptPath `
                -Arguments @('-TestSuite', 'Fake', '-Tag', 'Smoke', '-ExcludeTag', 'Slow')

            $run.ExitCode | Should -Be 0
            (Test-Path -Path $sandbox.InvokeTestParamsPath) | Should -BeTrue
            (Test-Path -Path $sandbox.InvokeGateParamsPath) | Should -BeFalse

            $invokeTestParams = Get-Content -Path $sandbox.InvokeTestParamsPath -Raw | ConvertFrom-Json
            $invokeTestParams.CoverageMode | Should -Be 'Full'
            @($invokeTestParams.Tag) | Should -Contain 'Smoke'
            @($invokeTestParams.ExcludeTag) | Should -Contain 'Slow'
        }

        It 'runs Invoke-NewCodeGate when effective mode is NewCodeAnalysis and passes resolved coverage path' {
            $sandbox = New-TestCoverageSandbox `
                -RootPath (Join-Path -Path $TestDrive -ChildPath 'coverage-new-code') `
                -CoverageMode 'NewCodeAnalysis' `
                -CoverageOutputPath 'artifacts/coverage/Fake.coverage.xml'

            $run = Invoke-ExternalPwshScript `
                -WorkingDirectory $sandbox.RootPath `
                -ScriptPath $sandbox.EntryScriptPath `
                -Arguments @('-TestSuite', 'Fake')

            $run.ExitCode | Should -Be 0
            (Test-Path -Path $sandbox.InvokeGateParamsPath) | Should -BeTrue

            $invokeGateParams = Get-Content -Path $sandbox.InvokeGateParamsPath -Raw | ConvertFrom-Json
            $invokeGateParams.BaseRef | Should -Be 'origin/main'
            $invokeGateParams.CoveragePath | Should -Be (Join-Path -Path $sandbox.RootPath -ChildPath 'artifacts/coverage/Fake.coverage.xml')
        }
    }

    Context 'Invoke-NewCodeGate evaluation' {
        It 'passes when changed lines are covered above threshold' {
            $sandbox = New-NewCodeGateSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'gate-pass') -LineCoverageValue '1'
            $originalPath = $env:PATH

            try {
                $env:PATH = "{0};{1}" -f $sandbox.RootPath, $originalPath
                $run = Invoke-ExternalPwshScript `
                    -WorkingDirectory $sandbox.RootPath `
                    -ScriptPath $sandbox.EntryScriptPath `
                    -Arguments @('-BaseRef', 'origin/main', '-CoveragePath', $sandbox.CoveragePath, '-MinimumCoveragePercent', '50')
            } finally {
                $env:PATH = $originalPath
            }

            $run.ExitCode | Should -Be 0
            $run.Text | Should -Match 'New-code coverage gate passed'
        }

        It 'fails when changed measurable lines are below threshold' {
            $sandbox = New-NewCodeGateSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'gate-fail') -LineCoverageValue '0'
            $originalPath = $env:PATH

            try {
                $env:PATH = "{0};{1}" -f $sandbox.RootPath, $originalPath
                $run = Invoke-ExternalPwshScript `
                    -WorkingDirectory $sandbox.RootPath `
                    -ScriptPath $sandbox.EntryScriptPath `
                    -Arguments @('-BaseRef', 'origin/main', '-CoveragePath', $sandbox.CoveragePath, '-MinimumCoveragePercent', '50')
            } finally {
                $env:PATH = $originalPath
            }

            $run.ExitCode | Should -Be 1
            $run.Text | Should -Match 'New-code coverage gate failed'
        }
    }
}
