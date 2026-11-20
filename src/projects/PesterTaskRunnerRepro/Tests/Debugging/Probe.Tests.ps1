BeforeAll {
    $HarnessPath = Join-Path $PSScriptRoot '..\Fixtures\ScopeHarness.psm1'
    Import-Module -Name $HarnessPath -Force
    $Root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $FirstRoot = Join-Path $Root 'First\RulePackage'
    $SecondRoot = Join-Path $Root 'Second\RulePackage'
    $null = New-Item -Path $FirstRoot, $SecondRoot -ItemType Directory -Force
    $FirstPath = Join-Path $FirstRoot 'RulePackageRules.psm1'
    $SecondPath = Join-Path $SecondRoot 'RulePackageRules.psm1'
    @'
$global:DetachedOnRemoveCount = 0
$ExecutionContext.SessionState.Module.OnRemove = {
    $global:DetachedOnRemoveCount++
}
function Test-ReproRule { 'first' }
Export-ModuleMember -Function Test-ReproRule
'@ | Set-Content -LiteralPath $FirstPath
    "function Test-ReproRule { 'second' }`nExport-ModuleMember -Function Test-ReproRule" |
        Set-Content -LiteralPath $SecondPath
}

AfterAll {
    Remove-Variable -Name DetachedOnRemoveCount -Scope Global -ErrorAction SilentlyContinue
    Remove-Module -Name ScopeHarness -Force -ErrorAction SilentlyContinue
}

Describe 'Remove-Module on detached module' {
    It 'reports each removal form' {
        Import-Module -Name $FirstPath -ErrorAction Stop
        $null = New-Module -ArgumentList $SecondPath -ScriptBlock {
            param ($Path)
            $null = Import-Module -Name $Path -Scope Local
            Export-ModuleMember -Function @() -Alias @()
        }
        InModuleScope ScopeHarness -Parameters @{ Root = $Root } {
            param ($Root)
            Get-Module -All |
                Where-Object { $_.ModuleBase -like "$Root\*" } |
                Remove-Module -Force
        }

        $Command = Get-Command Test-ReproRule -ErrorAction SilentlyContinue
        $Module = $Command.Module
        $CountBefore = $global:DetachedOnRemoveCount

        Remove-Module -ModuleInfo $Module -Force -ErrorAction Stop
        $AfterModuleInfo = Get-Command Test-ReproRule -ErrorAction SilentlyContinue

        Remove-Module -Name $Module.Name -Force -ErrorAction SilentlyContinue
        $AfterName = Get-Command Test-ReproRule -ErrorAction SilentlyContinue

        $InsideError = $null
        try {
            & $Module { Remove-Module -ModuleInfo $ExecutionContext.SessionState.Module -Force }
        } catch {
            $InsideError = $_.Exception.Message
        }
        $AfterInside = Get-Command Test-ReproRule -ErrorAction SilentlyContinue

        Write-Host (
            "REMOVE onRemoveBefore=$CountBefore onRemoveAfter=$global:DetachedOnRemoveCount " +
            "afterModuleInfo=$($null -ne $AfterModuleInfo) afterName=$($null -ne $AfterName) " +
            "afterInside=$($null -ne $AfterInside) insideError=$InsideError"
        )

        $AfterInside | Should -Not -BeNullOrEmpty
    }
}
