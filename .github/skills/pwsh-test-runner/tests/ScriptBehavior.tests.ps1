Describe 'test-runner skill scripts' {
    BeforeAll {
        $script:InvokeTestSource = Join-Path -Path $PSScriptRoot -ChildPath '../../../../tools/Invoke-Test.ps1'
        $script:InvokeTestCoverageSource = Join-Path -Path $PSScriptRoot -ChildPath '../scripts/Invoke-TestCoverage.ps1'
        $script:InvokeNewCodeGateSource = Join-Path -Path $PSScriptRoot -ChildPath '../scripts/Invoke-NewCodeGate.ps1'

        function script:Invoke-ExternalPwshScript {
            param(
                [Parameter(Mandatory)]
                [string] $WorkingDirectory,

                [Parameter(Mandatory)]
                [string] $ScriptPath,

                [string[]] $Arguments = @(),

                [string] $ModulePath
            )

            Push-Location -Path $WorkingDirectory
            $originalModulePath = $env:PSModulePath
            try {
                if ($PSBoundParameters.ContainsKey('ModulePath')) {
                    $env:PSModulePath = $ModulePath
                }
                $output = @(& pwsh -NoProfile -NonInteractive -File $ScriptPath @Arguments 2>&1)
                $exitCode = $LASTEXITCODE
            } finally {
                $env:PSModulePath = $originalModulePath
                Pop-Location
            }

            return [pscustomobject] @{
                ExitCode = $exitCode
                Output = @($output)
                Text = ($output -join [Environment]::NewLine)
            }
        }

        function script:New-TestRunnerSandbox {
            param(
                [Parameter(Mandatory)]
                [string] $RootPath
            )

            $scriptsPath = Join-Path -Path $RootPath -ChildPath 'scripts'
            $suitePath = Join-Path -Path $RootPath -ChildPath 'suite'
            $testsPath = Join-Path -Path $suitePath -ChildPath 'Tests'
            New-Item -Path $scriptsPath, $testsPath -ItemType Directory -Force | Out-Null

            Copy-Item -Path $script:InvokeTestSource -Destination (Join-Path -Path $scriptsPath -ChildPath 'Invoke-Test.ps1') -Force

            @"
{
    "isRoot": true,
    "TestSuites": [
        {
            "Name": "Fake",
            "ConfigPath": "suite/pester.json"
        }
    ]
}
"@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'pester.json') -NoNewline

            @"
{
    "TestSuite": "Fake",
    "Run": {
        "Path": [
            "Tests"
        ]
    },
    "Output": {
        "Verbosity": "None"
    }
}
"@ | Set-Content -Path (Join-Path -Path $suitePath -ChildPath 'pester.json') -NoNewline

        "Describe 'Selected test' { It 'passes' { `$true | Should -BeTrue } }" |
        Set-Content -Path (Join-Path -Path $testsPath -ChildPath 'Selected.tests.ps1') -NoNewline
        "Describe 'Unselected test' { It 'fails' { `$true | Should -BeFalse } }" |
        Set-Content -Path (Join-Path -Path $testsPath -ChildPath 'Unselected.tests.ps1') -NoNewline

        return [pscustomobject] @{
        RootPath = $RootPath
        EntryScriptPath = (Join-Path -Path $scriptsPath -ChildPath 'Invoke-Test.ps1')
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
            $toolsPath = Join-Path -Path $RootPath -ChildPath 'tools'
            New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
            New-Item -Path $toolsPath -ItemType Directory -Force | Out-Null

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
"@ | Set-Content -Path (Join-Path -Path $toolsPath -ChildPath 'Invoke-Test.ps1') -NoNewline

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
                InvokeTestParamsPath = (Join-Path -Path $toolsPath -ChildPath 'invoke-test.params.json')
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

    Context 'Invoke-Test execution options' {
        It 'accepts Suite as an alias and limits execution to a suite-relative path' {
            $sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'focused-run')

            $run = Invoke-ExternalPwshScript `
                -WorkingDirectory $sandbox.RootPath `
                -ScriptPath $sandbox.EntryScriptPath `
                -Arguments @('-Suite', 'Fake', '-Path', 'Tests/Selected.tests.ps1')

            $run.Text | Should -Match 'Test Suite: Fake'
            $run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
            $run.Text | Should -Not -Match 'Unselected test'
        }

        It 'enables detailed Pester console output when requested' {
            $sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'detailed-run')

            $run = Invoke-ExternalPwshScript `
                -WorkingDirectory $sandbox.RootPath `
                -ScriptPath $sandbox.EntryScriptPath `
                -Arguments @('-TestSuite', 'Fake', '-Path', 'Tests/Selected.tests.ps1', '-DetailedOutput')

            $run.Text | Should -Match 'Starting discovery in'
            $run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
        }

        It 'restores the edition-specific user module path before Pester discovery' {
            $sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'module-path-run')
            $userModulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
            $modulePathWithoutUserRoot = @(
                $env:PSModulePath -split [IO.Path]::PathSeparator |
                    Where-Object { $_ -ne $userModulePath }
            ) -join [IO.Path]::PathSeparator

            $run = Invoke-ExternalPwshScript `
                -WorkingDirectory $sandbox.RootPath `
                -ScriptPath $sandbox.EntryScriptPath `
                -Arguments @('-Suite', 'Fake', '-Path', 'Tests/Selected.tests.ps1') `
                -ModulePath $modulePathWithoutUserRoot

            $run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
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
