Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'New-PleaseWorkTaskSnapshot' {
        It 'captures TaskFile data, definitions, modules, aliases, and tasks' {
            $ModulePath = Join-Path $TestDrive 'SnapshotDependency.psm1'
            @'
function Get-SnapshotModuleValue {
    'module-value'
}
Export-ModuleMember -Function Get-SnapshotModuleValue
'@ | Set-Content -LiteralPath $ModulePath
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
            @"
`$PleaseConfig = @{ BaseRef = 'main' }
`$SnapshotSettings = @{
    Name = 'build'
    Values = @(1, 2)
}
function Get-SnapshotSetting {
    `$SnapshotSettings.Name
}
Set-Alias -Name snapshot-setting -Value Get-SnapshotSetting
Import-Module '$ModulePath'

build: {
    Get-SnapshotSetting
}
"@ | Set-Content -LiteralPath $TaskFile

            $Snapshot = New-PleaseWorkTaskSnapshot -Path $TaskFile

            $Snapshot.TaskFilePath | Should -Be $TaskFile
            $Snapshot.Config.BaseRef | Should -Be 'main'
            ($Snapshot.Variables | Where-Object Name -eq SnapshotSettings).Value.Name |
                Should -Be 'build'
            $Snapshot.Functions.Name | Should -Contain 'Get-SnapshotSetting'
            $Snapshot.Functions.Name | Should -Not -Contain 'Get-SnapshotModuleValue'
            $Snapshot.Aliases.Name | Should -Contain 'snapshot-setting'
            $Snapshot.Modules.Path | Should -Contain $ModulePath
            $Snapshot.Tasks.Name | Should -Be @('build')
            $Snapshot.Tasks.ScriptBlockText | Should -Match 'Get-SnapshotSetting'
        }

        It 'returns independent copies of mutable TaskFile values' {
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
            @'
$SnapshotSettings = @{
    Name = 'initial'
    Values = [System.Collections.Generic.List[int]] @(1, 2)
    Empty = @()
}
$SnapshotOrdered = [ordered] @{ Second = 2; First = 1 }
$SnapshotList = [System.Collections.Generic.List[string]] @('one')
build: { 'build' }
'@ | Set-Content -LiteralPath $TaskFile

            $Snapshot = New-PleaseWorkTaskSnapshot -Path $TaskFile
            $Settings = ($Snapshot.Variables |
                Where-Object Name -eq SnapshotSettings).Value
            $Settings.Values[0] = 9
            $Settings['Name'] = 'changed'

            $FreshSnapshot = New-PleaseWorkTaskSnapshot -Path $TaskFile
            $FreshSettings = ($FreshSnapshot.Variables |
                Where-Object Name -eq SnapshotSettings).Value
            $FreshSettings.Name | Should -Be 'initial'
            $FreshSettings.Values.Count | Should -Be 2
            $FreshSettings.Values[0] | Should -Be 1
            $FreshSettings.Values[1] | Should -Be 2
            $FreshSettings['Empty'].GetType().FullName |
                Should -Be 'System.Object[]'
            $FreshSettings['Empty'].Count | Should -Be 0
            $Ordered = ($FreshSnapshot.Variables |
                Where-Object Name -eq SnapshotOrdered).Value
            $Ordered.GetType().FullName |
                Should -Be 'System.Collections.Specialized.OrderedDictionary'
            @($Ordered.Keys) | Should -Be @('Second', 'First')
            $List = ($FreshSnapshot.Variables |
                Where-Object Name -eq SnapshotList).Value
            ($List -is [System.Collections.Generic.List[string]]) | Should -BeTrue
            $List.Add('two')
            $List | Should -Be @('one', 'two')
        }

        It 'rejects live object references that cannot be recreated safely' {
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
            @'
$SnapshotFile = [System.IO.FileInfo]::new('snapshot.txt')
build: { 'build' }
'@ | Set-Content -LiteralPath $TaskFile

            { New-PleaseWorkTaskSnapshot -Path $TaskFile } |
                Should -Throw '*SnapshotFile*unsupported type*System.IO.FileInfo*'
        }

        It 'propagates a terminating TaskFile setup error' {
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
            @'
Write-Error 'setup failed'
build: { 'build' }
'@ | Set-Content -LiteralPath $TaskFile

            { New-PleaseWorkTaskSnapshot -Path $TaskFile } |
                Should -Throw '*setup failed*'
        }

        It 'rejects a TaskFile dynamic module without a source path' {
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
            @'
New-Module -Name SnapshotDynamic -ScriptBlock {
    function Get-SnapshotDynamicValue { 'dynamic' }
    Export-ModuleMember -Function Get-SnapshotDynamicValue
} | Import-Module
build: { Get-SnapshotDynamicValue }
'@ | Set-Content -LiteralPath $TaskFile

            { New-PleaseWorkTaskSnapshot -Path $TaskFile } |
                Should -Throw '*dynamic modules without a file source*SnapshotDynamic*'
        }

        It 'does not let runspace startup change PSModulePath' {
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
            'build: { "build" }' | Set-Content -LiteralPath $TaskFile
            $OriginalPSModulePath = $env:PSModulePath

            try {
                $env:PSModulePath = 'PleaseWorkSnapshotSentinel'
                $null = New-PleaseWorkTaskSnapshot -Path $TaskFile
                $env:PSModulePath | Should -Be 'PleaseWorkSnapshotSentinel'
            } finally {
                $env:PSModulePath = $OriginalPSModulePath
            }
        }
    }
}
