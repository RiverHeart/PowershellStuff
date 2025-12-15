if (-not $PSScriptRoot -ne $PWD) {
    Set-Location $PSScriptRoot
}

$Config = New-PesterConfiguration
$Config.TestRegistry.Enabled = $false
$Config.Run.Path = './Tests/'

Invoke-Pester -Configuration $Config
