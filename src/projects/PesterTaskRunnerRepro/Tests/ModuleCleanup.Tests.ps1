BeforeAll {
    $HarnessPath = Join-Path $PSScriptRoot 'Fixtures\ScopeHarness.psm1'
    Import-Module -Name $HarnessPath -Force

    $PackageRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $FirstPackageRoot = Join-Path $PackageRoot 'First\RulePackage'
    $SecondPackageRoot = Join-Path $PackageRoot 'Second\RulePackage'
    $null = New-Item -Path $FirstPackageRoot -ItemType Directory -Force
    $null = New-Item -Path $SecondPackageRoot -ItemType Directory -Force

    $FirstRulesPath = Join-Path $FirstPackageRoot 'RulePackageRules.psm1'
    $SecondRulesPath = Join-Path $SecondPackageRoot 'RulePackageRules.psm1'
    @'
function Test-ReproRule { 'first' }
Export-ModuleMember -Function Test-ReproRule
'@ | Set-Content -LiteralPath $FirstRulesPath
    @'
function Test-ReproRule { 'second' }
Export-ModuleMember -Function Test-ReproRule
'@ | Set-Content -LiteralPath $SecondRulesPath

}

AfterAll {
    Get-Module -All |
        Where-Object { $_.ModuleBase -like "$PackageRoot\*" } |
        Remove-Module -Force -ErrorAction SilentlyContinue

    Remove-Module -Name ScopeHarness -Force -ErrorAction SilentlyContinue
}

Describe 'module cleanup across module scopes' {
    It 'does not leave commands when modules are removed by discovery' {
        Import-Module -Name $FirstRulesPath -ErrorAction Stop

        New-Module -ArgumentList $SecondRulesPath -ScriptBlock {
            param ($Path)
            $Instance = Import-Module -Name $Path -Scope Local -PassThru -ErrorAction Stop
            Export-ModuleMember -Function @() -Alias @()
            $Instance
        } -ErrorAction Stop |
            Import-Module -Force -ErrorAction Stop

        $FoundModules = @(
            Get-Module -All |
                Where-Object { $_.ModuleBase -like "$PackageRoot\*" }
        )
        $FoundModules | Should -HaveCount 2

        InModuleScope ScopeHarness -Parameters @{ Root = $PackageRoot } {
            param ($Root)
            Get-Module -All |
                Where-Object { $_.ModuleBase -like "$Root\*" } |
                Remove-Module -Force
        }

        Get-Module -All |
            Where-Object { $_.ModuleBase -like "$PackageRoot\*" } |
            Should -BeNullOrEmpty

        Get-Command Test-ReproRule -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

}
