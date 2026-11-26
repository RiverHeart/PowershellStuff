BeforeAll {
    $ModuleManifest = Join-Path -Path $PSScriptRoot -ChildPath '../ModuleDevKit.psd1'
    Import-Module $ModuleManifest -Force -ErrorAction Stop
}

Describe 'ModuleDevKit smoke tests' {
    It 'exports the documented public commands' {
        $ExpectedCommands = @(
            'Build-MDKModule'
            'Compress-MDKModule'
            'Get-GitIgnoreFile'
            'Get-GitRepositoryRoot'
            'Invoke-MDKModuleBuild'
            'Invoke-MDKNewCodeGate'
            'Invoke-MDKTest'
            'Invoke-MDKTestCoverage'
            'Test-GitIgnoredPath'
        )

        $ActualCommands = @(
            Get-Command -Module ModuleDevKit |
                Select-Object -ExpandProperty Name
        )

        $ActualCommands | Should -Be $ExpectedCommands
    }

    It 'lists configured suites' {
        $Output = @(Invoke-MDKTest -ListSuites 6>&1) | Out-String

        $Output | Should -Match 'ModuleDevKit -> src/modules/ModuleDevKit/pester.json'
    }

    It 'runs a suite-relative focused test and restores the caller location' {
        $Sandbox = Join-Path -Path $TestDrive -ChildPath 'runner-sandbox'
        $SuiteDirectory = Join-Path -Path $Sandbox -ChildPath 'Suite'
        $TestsDirectory = Join-Path -Path $SuiteDirectory -ChildPath 'Tests'
        New-Item -Path $TestsDirectory -ItemType Directory -Force | Out-Null

        @'
{
    "isRoot": true,
    "TestSuites": [
        {
            "Name": "Smoke",
            "ConfigPath": "Suite/pester.json"
        }
    ]
}
'@ | Set-Content -Path (Join-Path -Path $Sandbox -ChildPath 'pester.json')

        @'
{
    "TestSuite": "Smoke",
    "Run": {
        "Path": [
            "Tests"
        ]
    },
    "Coverage": {
        "Path": [
            "Coverage.ps1"
        ],
        "OutputFormat": "JaCoCo",
        "OutputPath": "artifacts/coverage/Smoke.coverage.xml",
        "ExcludeTests": true
    }
}
'@ | Set-Content -Path (Join-Path -Path $SuiteDirectory -ChildPath 'pester.json')

        @'
function Test-SmokeCoverage {
    Write-Output $true
}
'@ | Set-Content -Path (Join-Path -Path $SuiteDirectory -ChildPath 'Coverage.ps1')

        @'
Describe 'Smoke' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '../Coverage.ps1')
    }

    It 'passes' {
        Test-SmokeCoverage | Should -BeTrue
    }
}
'@ | Set-Content -Path (Join-Path -Path $TestsDirectory -ChildPath 'Smoke.Tests.ps1')

        $EscapedSandbox = $Sandbox.Replace("'", "''")
        $EscapedManifest = $ModuleManifest.Replace("'", "''")
        $Command = @"
Import-Module -LiteralPath '$EscapedManifest' -Force -ErrorAction Stop
Set-Location -LiteralPath '$EscapedSandbox'
Invoke-MDKTest -Suite Smoke -CoverageMode Full -ExitOnError
if ((Get-Location).Path -ne '$EscapedSandbox') {
    throw 'Invoke-MDKTest did not restore the caller location.'
}
if (-not (Test-Path -LiteralPath '$EscapedSandbox/artifacts/coverage/Smoke.coverage.xml')) {
    throw 'Invoke-MDKTest did not create the configured coverage report.'
}
Invoke-MDKTestCoverage -TestSuite Smoke
"@

        $Output = @(& pwsh -NoProfile -NonInteractive -Command $Command 2>&1)
        $LASTEXITCODE | Should -Be 0
        $OutputText = $Output | Out-String
        $OutputText | Should -Match 'Tests Passed: 1, Failed: 0'
        $OutputText | Should -Match "Coverage Mode: Full"
    }
}