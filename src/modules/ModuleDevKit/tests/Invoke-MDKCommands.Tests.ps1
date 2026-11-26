BeforeAll {
    $ModuleManifest = Join-Path -Path $PSScriptRoot -ChildPath '../ModuleDevKit.psd1'
    Import-Module $ModuleManifest -Force -ErrorAction Stop

    function Invoke-ExternalPwshScript {
        param(
            [Parameter(Mandatory)]
            [string] $WorkingDirectory,

            [Parameter(Mandatory)]
            [string] $ScriptPath,

            [string[]] $Arguments = @(),

            [string] $ModulePath
        )

        Push-Location -Path $WorkingDirectory
        $OriginalModulePath = $env:PSModulePath
        try {
            if ($PSBoundParameters.ContainsKey('ModulePath')) {
                $env:PSModulePath = $ModulePath
            }

            $Output = @(& pwsh -NoProfile -NonInteractive -File $ScriptPath @Arguments 2>&1)
            $ExitCode = $LASTEXITCODE
        } finally {
            $env:PSModulePath = $OriginalModulePath
            Pop-Location
        }

        return [pscustomobject] @{
            ExitCode = $ExitCode
            Output = @($Output)
            Text = ($Output -join [Environment]::NewLine)
        }
    }

    function New-TestRunnerSandbox {
        param(
            [Parameter(Mandatory)]
            [string] $RootPath
        )

        $SuitePath = Join-Path -Path $RootPath -ChildPath 'Suite'
        $TestsPath = Join-Path -Path $SuitePath -ChildPath 'Tests'
        New-Item -Path $TestsPath -ItemType Directory -Force | Out-Null

        @'
{
    "isRoot": true,
    "TestSuites": [
        {
            "Name": "Fake",
            "ConfigPath": "Suite/pester.json"
        }
    ]
}
'@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'pester.json') -NoNewline

        @'
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
'@ | Set-Content -Path (Join-Path -Path $SuitePath -ChildPath 'pester.json') -NoNewline

        @'
Describe 'Selected test' {
    It 'passes' {
        $true | Should -BeTrue
    }
}
'@ | Set-Content -Path (Join-Path -Path $TestsPath -ChildPath 'Selected.tests.ps1') -NoNewline

        @'
Describe 'Unselected test' {
    It 'fails' {
        $true | Should -BeFalse
    }
}
'@ | Set-Content -Path (Join-Path -Path $TestsPath -ChildPath 'Unselected.tests.ps1') -NoNewline

        @'
Describe 'Broken discovery' {
    It 'never discovered' {
        $true | Should -BeTrue
'@ | Set-Content -Path (Join-Path -Path $TestsPath -ChildPath 'Broken.tests.ps1') -NoNewline

        @'
Describe 'Broken setup' {
    BeforeAll {
        throw 'setup boom'
    }

    It 'never runs' {
        $true | Should -BeTrue
    }
}
'@ | Set-Content -Path (Join-Path -Path $TestsPath -ChildPath 'Setup.tests.ps1') -NoNewline

        $EntryScriptPath = Join-Path -Path $RootPath -ChildPath 'Invoke-MDKTest.ps1'
        $EscapedManifest = $ModuleManifest.Replace("'", "''")
        @"
param(
    [Alias('Suite')]
    [string] `$TestSuite,

    [string[]] `$Path,
    [switch] `$ExitOnError,
    [switch] `$DetailedOutput
)

Import-Module -LiteralPath '$EscapedManifest' -Force -ErrorAction Stop
Invoke-MDKTest @PSBoundParameters
"@ | Set-Content -Path $EntryScriptPath -NoNewline

        return [pscustomobject] @{
            RootPath = $RootPath
            EntryScriptPath = $EntryScriptPath
        }
    }

    function New-CoverageSandbox {
        param(
            [Parameter(Mandatory)]
            [string] $RootPath,

            [string] $CoverageMode
        )

        New-Item -Path $RootPath -ItemType Directory -Force | Out-Null
        @'
{
  "isRoot": true,
  "TestSuites": [
    {
      "Name": "Fake",
      "ConfigPath": "suite.json"
    }
  ]
}
'@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'pester.json') -NoNewline

        $ModeLine = if ([string]::IsNullOrWhiteSpace($CoverageMode)) {
            ''
        } else {
            "`n    `"Mode`": `"$CoverageMode`","
        }

        @"
{
  "TestSuite": "Fake",
  "Run": {
    "Path": [
      "."
    ]
  },
  "Coverage": {${ModeLine}
    "Path": [
      "Coverage.ps1"
    ],
    "OutputPath": "artifacts/coverage/Fake.coverage.xml"
  }
}
"@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'suite.json') -NoNewline

        'function Test-Coverage { $true }' |
            Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'Coverage.ps1') -NoNewline
        @'
Describe 'Coverage' -Tag Smoke {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath 'Coverage.ps1')
    }

    It 'runs covered code' {
        Test-Coverage | Should -BeTrue
    }
}
'@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'Coverage.Tests.ps1') -NoNewline

        $EntryScriptPath = Join-Path -Path $RootPath -ChildPath 'Invoke-MDKTestCoverage.ps1'
        $EscapedManifest = $ModuleManifest.Replace("'", "''")
        @"
param(
    [string] `$TestSuite,
    [string] `$CoverageMode = 'FromConfig',
    [string] `$BaseRef = 'origin/main',
    [string[]] `$Tag,
    [string[]] `$ExcludeTag
)

Import-Module -LiteralPath '$EscapedManifest' -Force -ErrorAction Stop
Invoke-MDKTestCoverage @PSBoundParameters
"@ | Set-Content -Path $EntryScriptPath -NoNewline

        return [pscustomobject] @{
            RootPath = $RootPath
            EntryScriptPath = $EntryScriptPath
            CoveragePath = (
                Join-Path -Path $RootPath -ChildPath 'artifacts/coverage/Fake.coverage.xml'
            )
        }
    }

    function New-NewCodeGateSandbox {
        param(
            [Parameter(Mandatory)]
            [string] $RootPath,

            [Parameter(Mandatory)]
            [string] $LineCoverageValue
        )

        New-Item -Path $RootPath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $RootPath -ChildPath '.git') -ItemType Directory -Force | Out-Null

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

        @'
@echo off
if "%3"=="rev-parse" exit /b 0
if "%3"=="diff" (
    echo +++ b/src/sample.ps1
    echo @@ -0,0 +2 @@
    exit /b 0
)
exit /b 0
'@ | Set-Content -Path (Join-Path -Path $RootPath -ChildPath 'git.cmd') -NoNewline

        return [pscustomobject] @{
            RootPath = $RootPath
            CoveragePath = (Join-Path -Path $RootPath -ChildPath 'coverage.xml')
        }
    }
}

Describe 'Invoke-MDKTest' {
    It 'makes repository modules discoverable before parsing test files' -Tag RepositoryModulePath {
        $Sandbox = New-TestRunnerSandbox -RootPath (
            Join-Path -Path $TestDrive -ChildPath 'repository-module-path'
        )
        $ModuleDirectory = Join-Path -Path $Sandbox.RootPath -ChildPath 'src/modules/RunnerDependency'
        New-Item -Path $ModuleDirectory -ItemType Directory -Force | Out-Null
        'class RunnerDependencyType {}' |
            Set-Content -Path (Join-Path -Path $ModuleDirectory -ChildPath 'RunnerDependency.psm1') -NoNewline
        @'
using module RunnerDependency
Describe 'Repository dependency' {
    It 'resolves dependency classes without a profile' {
        [RunnerDependencyType]::new().GetType().Name | Should -Be 'RunnerDependencyType'
    }
}
'@ | Set-Content -Path (Join-Path -Path $Sandbox.RootPath -ChildPath 'Suite/Tests/Selected.tests.ps1') -NoNewline

        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @('-Suite', 'Fake', '-Path', 'Tests/Selected.tests.ps1', '-ExitOnError')

        $Run.ExitCode | Should -Be 0
        $Run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
    }

    It 'accepts Suite as an alias and limits execution to a suite-relative path' {
        $Sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'focused-run')

        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @('-Suite', 'Fake', '-Path', 'Tests/Selected.tests.ps1')

        $Run.Text | Should -Match 'Test Suite: Fake'
        $Run.Text | Should -Match 'PowerShell: \d+\.\d+\.\d+'
        $Run.Text | Should -Match 'Pester: 5\.'
        $Run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
        $Run.Text | Should -Not -Match 'Unselected test'
    }

    It 'does not exit the host for failed tests by default' {
        $Sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'default-failure-run')
        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @('-Suite', 'Fake', '-Path', 'Tests/Unselected.tests.ps1')

        $Run.ExitCode | Should -Be 0
        $Run.Text | Should -Match 'Tests Passed: 0, Failed: 1'
    }

    It 'exits with code 2 for failed test results when requested' {
        $Sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'exit-on-error-run')
        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @('-Suite', 'Fake', '-Path', 'Tests/Unselected.tests.ps1', '-ExitOnError')

        $Run.ExitCode | Should -Be 2
        $Run.Text | Should -Match 'Tests Passed: 0, Failed: 1'
    }

    It 'returns exit code 0 with ExitOnError when tests pass' {
        $Sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'exit-on-success-run')
        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @('-Suite', 'Fake', '-Path', 'Tests/Selected.tests.ps1', '-ExitOnError')

        $Run.ExitCode | Should -Be 0
        $Run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
    }

    It 'enables detailed Pester console output when requested' {
        $Sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'detailed-run')
        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @('-TestSuite', 'Fake', '-Path', 'Tests/Selected.tests.ps1', '-DetailedOutput')

        $Run.Text | Should -Match 'Starting discovery in'
        $Run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
    }

    It 'reports a discovery failure as a failed run instead of all tests passed' {
        $Sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'discovery-failure-run')
        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @(
                '-Suite'
                'Fake'
                '-Path'
                'Tests/Broken.tests.ps1,Tests/Selected.tests.ps1'
                '-ExitOnError'
            )

        $Run.ExitCode | Should -Be 2
        $Run.Text | Should -Match '\[-\] Container failed: .*Broken\.tests\.ps1'
        $Run.Text | Should -Match 'Broken\.tests\.ps1:\d+: Missing closing'
        $Run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
        $Run.Text | Should -Match 'Failed Containers: 1, Failed Blocks: 0'
        $Run.Text | Should -Not -Match 'All tests passed'
    }

    It 'reports a failed block setup with its error and the affected test' {
        $Sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'setup-failure-run')
        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @('-Suite', 'Fake', '-Path', 'Tests/Setup.tests.ps1', '-ExitOnError')

        $Run.ExitCode | Should -Be 2
        $Run.Text | Should -Match '\[-\] Block failed: Broken setup\s+setup boom'
        $Run.Text | Should -Match '\[-\] Broken setup\.never runs \(Failed\)\s+setup boom'
        $Run.Text | Should -Match 'Failed Containers: 0, Failed Blocks: 1'
    }

    It 'splits comma-joined Path entries' {
        $Sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'comma-path-run')
        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @(
                '-Suite'
                'Fake'
                '-Path'
                'Tests/Selected.tests.ps1, Tests/Unselected.tests.ps1'
            )

        $Run.Text | Should -Match 'Selected\.tests\.ps1'
        $Run.Text | Should -Match 'Unselected\.tests\.ps1'
        $Run.Text | Should -Match 'Tests Passed: 1, Failed: 1'
    }

    It 'restores the edition-specific user module path before Pester discovery' {
        $Sandbox = New-TestRunnerSandbox -RootPath (Join-Path -Path $TestDrive -ChildPath 'module-path-run')
        $UserModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'PowerShell/Modules'
        @'
Describe 'Restored module path' {
    It 'contains the expected CurrentUser module path' {
        @($env:PSModulePath -split [IO.Path]::PathSeparator) |
            Should -Contain $env:EXPECTED_USER_MODULE_PATH
    }
}
'@ | Set-Content -Path (Join-Path -Path $Sandbox.RootPath -ChildPath 'Suite/Tests/Selected.tests.ps1') -NoNewline

        $ModulePathWithoutUserRoot = @(
            $env:PSModulePath -split [IO.Path]::PathSeparator |
                Where-Object { $_ -ne $UserModulePath }
        ) -join [IO.Path]::PathSeparator

        $OriginalExpectedUserModulePath = $env:EXPECTED_USER_MODULE_PATH
        try {
            $env:EXPECTED_USER_MODULE_PATH = $UserModulePath
            $Run = Invoke-ExternalPwshScript `
                -WorkingDirectory $Sandbox.RootPath `
                -ScriptPath $Sandbox.EntryScriptPath `
                -Arguments @('-Suite', 'Fake', '-Path', 'Tests/Selected.tests.ps1') `
                -ModulePath $ModulePathWithoutUserRoot
        } finally {
            $env:EXPECTED_USER_MODULE_PATH = $OriginalExpectedUserModulePath
        }

        $Run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
    }
}

Describe 'Invoke-MDKTestCoverage' {
    It 'runs Invoke-MDKTest with Full coverage and skips the gate for Full mode' {
        $Sandbox = New-CoverageSandbox -RootPath (
            Join-Path -Path $TestDrive -ChildPath 'coverage-full'
        )
        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @('-TestSuite', 'Fake', '-Tag', 'Smoke', '-ExcludeTag', 'Slow')

        $Run.ExitCode | Should -Be 0
        $Run.Text | Should -Match 'Coverage Mode: Full'
        $Run.Text | Should -Match 'Tests Passed: 1, Failed: 0'
        (Test-Path -LiteralPath $Sandbox.CoveragePath) | Should -BeTrue
    }

    It 'runs the gate with the resolved coverage path in NewCodeAnalysis mode' {
        $Sandbox = New-CoverageSandbox `
            -RootPath (Join-Path -Path $TestDrive -ChildPath 'coverage-new-code') `
            -CoverageMode 'NewCodeAnalysis'
        & git -C $Sandbox.RootPath init --quiet
        & git -C $Sandbox.RootPath add --all
        & git -C $Sandbox.RootPath -c user.name=Test -c user.email=test@example.com commit --quiet -m Initial

        $Run = Invoke-ExternalPwshScript `
            -WorkingDirectory $Sandbox.RootPath `
            -ScriptPath $Sandbox.EntryScriptPath `
            -Arguments @('-TestSuite', 'Fake', '-BaseRef', 'HEAD')

        $Run.ExitCode | Should -Be 0
        $Run.Text | Should -Match "Coverage Mode: NewCodeAnalysis"
        $Run.Text | Should -Match 'No new lines found after filters. Gate passed.'
        (Test-Path -LiteralPath $Sandbox.CoveragePath) | Should -BeTrue
    }
}

Describe 'Invoke-MDKNewCodeGate' {
    It 'passes when changed lines are covered above threshold' {
        $Sandbox = New-NewCodeGateSandbox `
            -RootPath (Join-Path -Path $TestDrive -ChildPath 'gate-pass') `
            -LineCoverageValue '1'
        $OriginalPath = $env:PATH

        try {
            $env:PATH = '{0};{1}' -f $Sandbox.RootPath, $OriginalPath
            Push-Location -Path $Sandbox.RootPath
            $Output = Invoke-MDKNewCodeGate `
                -BaseRef origin/main `
                -CoveragePath $Sandbox.CoveragePath `
                -MinimumCoveragePercent 50 `
                6>&1
        } finally {
            Pop-Location
            $env:PATH = $OriginalPath
        }

        ($Output | Out-String) | Should -Match 'New-code coverage gate passed'
    }

    It 'fails when changed measurable lines are below threshold' {
        $Sandbox = New-NewCodeGateSandbox `
            -RootPath (Join-Path -Path $TestDrive -ChildPath 'gate-fail') `
            -LineCoverageValue '0'
        $OriginalPath = $env:PATH

        try {
            $env:PATH = '{0};{1}' -f $Sandbox.RootPath, $OriginalPath
            Push-Location -Path $Sandbox.RootPath
            {
                Invoke-MDKNewCodeGate `
                    -BaseRef origin/main `
                    -CoveragePath $Sandbox.CoveragePath `
                    -MinimumCoveragePercent 50
            } | Should -Throw '*New-code coverage gate failed*'
        } finally {
            Pop-Location
            $env:PATH = $OriginalPath
        }
    }
}
