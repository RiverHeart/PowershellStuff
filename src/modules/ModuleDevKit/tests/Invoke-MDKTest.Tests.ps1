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
            'New-MDKProject'
            'Test-GitIgnoredPath'
        )

        $ActualCommands = @(
            Get-Command -Module ModuleDevKit |
                Select-Object -ExpandProperty Name
        )

        $ActualCommands | Should -Be $ExpectedCommands
    }

    It 'creates a standalone project test config with a direct Run target' {
        New-MDKProject -Name BootstrapProject -Path $TestDrive -Confirm:$false

        $ProjectRoot = Join-Path -Path $TestDrive -ChildPath 'BootstrapProject'
        $PesterConfig = Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot 'pester.json') |
            ConvertFrom-Json

        $PesterConfig.isRoot | Should -BeTrue
        $PesterConfig.Run.Path | Should -Be @('tests')
        (Test-Path -LiteralPath (Join-Path $ProjectRoot 'tests') -PathType Container) |
            Should -BeTrue
    }

    It 'lists configured projects and test targets' {
        $EscapedModuleManifest = $ModuleManifest.Replace("'", "''")
        $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
        $EscapedRepositoryRoot = $RepositoryRoot.Replace("'", "''")
        $Command = @"
Import-Module -Name '$EscapedModuleManifest' -Force -ErrorAction Stop
Set-Location -LiteralPath '$EscapedRepositoryRoot'
Invoke-MDKTest -ListSuites
"@
        $Output = @(& pwsh -NoProfile -NonInteractive -Command $Command 2>&1) | Out-String

        $Output | Should -Match 'ModuleDevKit -> .*src[\\/]+modules[\\/]+ModuleDevKit[\\/]+pester\.json'
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
Import-Module -Name '$EscapedManifest' -Force -ErrorAction Stop
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

    It 'runs all configured projects without a suite selector and supports project suites' {
        $Sandbox = Join-Path -Path $TestDrive -ChildPath 'project-runner-sandbox'
        $FirstProject = Join-Path -Path $Sandbox -ChildPath 'First'
        $FirstUnitTests = Join-Path -Path $FirstProject -ChildPath 'Tests/Unit'
        $FirstIntegrationTests = Join-Path -Path $FirstProject -ChildPath 'Tests/Integration'
        $SecondProject = Join-Path -Path $Sandbox -ChildPath 'Second'
        $SecondTests = Join-Path -Path $SecondProject -ChildPath 'Tests'
        $SingleProject = Join-Path -Path $Sandbox -ChildPath 'Single'
        $SingleTests = Join-Path -Path $SingleProject -ChildPath 'tests'
        New-Item -Path $FirstUnitTests, $FirstIntegrationTests, $SecondTests, $SingleTests `
            -ItemType Directory -Force | Out-Null

        @'
{
    "isRoot": true,
    "Projects": [
        {
            "Name": "First",
            "ConfigPath": "First/pester.json"
        },
        {
            "Name": "Second",
            "ConfigPath": "Second/pester.json"
        }
    ]
}
'@ | Set-Content -Path (Join-Path -Path $Sandbox -ChildPath 'pester.json')

        @'
{
    "TestSuites": [
        {
            "Name": "Unit",
            "Run": {
                "Path": ["Tests/Unit"]
            },
            "Coverage": {
                "Path": ["Coverage.ps1"],
                "OutputFormat": "JaCoCo",
                "ExcludeTests": true
            }
        },
        {
            "Name": "Integration",
            "Run": {
                "Path": ["Tests/Integration"]
            }
        }
    ]
}
'@ | Set-Content -Path (Join-Path -Path $FirstProject -ChildPath 'pester.json')

        @'
function Get-UnitCoverage {
    Write-Output $true
}
'@ | Set-Content -Path (Join-Path -Path $FirstProject -ChildPath 'Coverage.ps1')

        @'
{
    "Run": {
        "Path": ["Tests"]
    }
}
'@ | Set-Content -Path (Join-Path -Path $SecondProject -ChildPath 'pester.json')

        @'
{
    "isRoot": true,
    "Run": {
        "Path": ["tests"]
    }
}
'@ | Set-Content -Path (Join-Path -Path $SingleProject -ChildPath 'pester.json')

        @'
Describe 'First unit suite' {
    BeforeAll {
        . (Join-Path -Path $PSScriptRoot -ChildPath '../../Coverage.ps1')
    }

    It 'passes' {
        Get-UnitCoverage | Should -BeTrue
    }
}
'@ | Set-Content -Path (Join-Path -Path $FirstUnitTests -ChildPath 'Unit.Tests.ps1')

        @'
Describe 'First integration suite' {
    It 'passes' {
        $true | Should -BeTrue
    }
}
'@ | Set-Content -Path (Join-Path -Path $FirstIntegrationTests -ChildPath 'Integration.Tests.ps1')

        @'
Describe 'Second project' {
    It 'passes' {
        $true | Should -BeTrue
    }
}
'@ | Set-Content -Path (Join-Path -Path $SecondTests -ChildPath 'Second.Tests.ps1')

        @'
Describe 'Single project' {
    It 'passes' {
        $true | Should -BeTrue
    }
}
'@ | Set-Content -Path (Join-Path -Path $SingleTests -ChildPath 'Single.Tests.ps1')

        $EscapedSandbox = $Sandbox.Replace("'", "''")
        $EscapedModuleManifest = $ModuleManifest.Replace("'", "''")
        $Command = @"
Import-Module -Name '$EscapedModuleManifest' -Force -ErrorAction Stop
Set-Location -LiteralPath '$EscapedSandbox'
`$AllResults = @(Invoke-MDKTest -PassThru)
if (`$AllResults.Count -ne 3 -or (`$AllResults | Measure-Object -Property PassedCount -Sum).Sum -ne 3) {
    throw 'The no-selector run did not execute all three configured project suites.'
}
`$FirstResults = @(Invoke-MDKTest -Project First -PassThru)
if (`$FirstResults.Count -ne 2 -or (`$FirstResults | Measure-Object -Property PassedCount -Sum).Sum -ne 2) {
    throw 'Project selection without a suite selector did not run all of that project suites.'
}
`$UnitResults = @(Invoke-MDKTest -Project First -TestSuite Unit -PassThru)
if (`$UnitResults.Count -ne 1 -or `$UnitResults[0].PassedCount -ne 1) {
    throw 'Project and suite selection did not restrict execution to the Unit suite.'
}
Invoke-MDKTestCoverage -Project First -TestSuite Unit -CoverageMode Full
if (-not (Test-Path -LiteralPath (Join-Path '$EscapedSandbox' 'artifacts/coverage/First.Unit.coverage.xml'))) {
    throw 'Coverage did not resolve a project and suite from the Projects manifest.'
}
Set-Location -LiteralPath (Join-Path '$EscapedSandbox' 'Single')
`$SingleResults = @(Invoke-MDKTest -PassThru)
if (`$SingleResults.Count -ne 1 -or `$SingleResults[0].PassedCount -ne 1) {
    throw 'A standalone Run config did not execute without a suite selector.'
}
"@

        $Output = @(& pwsh -NoProfile -NonInteractive -Command $Command 2>&1)
        $LASTEXITCODE | Should -Be 0
        ($Output | Out-String) | Should -Match 'Tests Passed: 1, Failed: 0'
    }
}