BeforeAll {
    $HarnessPath = Join-Path $PSScriptRoot 'Fixtures\ScopeHarness.psm1'
    Import-Module -Name $HarnessPath -Force

    $PackageRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $FirstPackageRoot = Join-Path $PackageRoot 'First\RulePackage'
    $SecondPackageRoot = Join-Path $PackageRoot 'Second\RulePackage'
    $null = New-Item -Path $FirstPackageRoot -ItemType Directory -Force
    $null = New-Item -Path $SecondPackageRoot -ItemType Directory -Force

    $FirstRulesPath = Join-Path $FirstPackageRoot 'ReferenceRulePackageRules.psm1'
    $SecondRulesPath = Join-Path $SecondPackageRoot 'ReferenceRulePackageRules.psm1'
    @'
function Test-ReproReferenceRule { 'first' }
Export-ModuleMember -Function Test-ReproReferenceRule
'@ | Set-Content -LiteralPath $FirstRulesPath
    @'
function Test-ReproReferenceRule { 'second' }
Export-ModuleMember -Function Test-ReproReferenceRule
'@ | Set-Content -LiteralPath $SecondRulesPath

    $script:FirstModule = Import-Module `
        -Name $FirstRulesPath `
        -PassThru `
        -ErrorAction Stop

    $script:WrapperModule = & {
        New-Module `
            -ArgumentList $SecondRulesPath `
            -ScriptBlock {
                param ($Path)
                Import-Module -Name $Path -Scope Local -ErrorAction Stop
                Export-ModuleMember -Function @() -Alias @()
            } `
            -ErrorAction Stop
    } | Import-Module -Force -PassThru -ErrorAction Stop
}

AfterAll {
    Remove-Module `
        -ModuleInfo $script:FirstModule, $script:WrapperModule `
        -Force `
        -ErrorAction Stop

    $RemainingModules = @(
        Get-Module -All |
            Where-Object { $_.ModuleBase -like "$PackageRoot\*" }
    )
    $RemainingCommands = @(
        Get-Command Test-ReproReferenceRule -All -ErrorAction SilentlyContinue
    )
    Remove-Module -Name ScopeHarness -Force -ErrorAction SilentlyContinue

    if ($RemainingModules.Count -gt 0 -or $RemainingCommands.Count -gt 0) {
        throw (
            'Retained PSModuleInfo cleanup left ' +
            "$($RemainingModules.Count) module(s) and " +
            "$($RemainingCommands.Count) command(s)."
        )
    }
}

Describe 'module cleanup through retained PSModuleInfo references' {
    It 'registers both modules referenced in script scope' {
        @(
            Get-Module -All |
                Where-Object { $_.ModuleBase -like "$PackageRoot\*" }
        ) | Should -HaveCount 2
    }
}
