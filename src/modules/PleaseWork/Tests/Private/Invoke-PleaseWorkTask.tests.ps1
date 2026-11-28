Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'Invoke-PleaseWorkTask' {
        BeforeAll {
            $ModulePath = Join-Path $TestDrive 'SnapshotDependency.psm1'
            @'
function Get-SnapshotModuleValue {
    'module-value'
}
Export-ModuleMember -Function Get-SnapshotModuleValue
'@ | Set-Content -LiteralPath $ModulePath
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
            @"
`$SnapshotState = @{ Count = 0 }
function Get-SnapshotState {
    `$SnapshotState.Count
}
Import-Module '$ModulePath'

build: {
    param ([string] `$Configuration)

    `$SnapshotState.Count++
    [pscustomobject] @{
        Configuration = `$Configuration
        Count = Get-SnapshotState
        ModuleValue = Get-SnapshotModuleValue
    }
}
"@ | Set-Content -LiteralPath $TaskFile
            $Snapshot = New-PleaseWorkTaskSnapshot -Path $TaskFile
        }

        It 'recreates TaskFile state and definitions in a fresh runspace' {
            $Result = $null

            $Output = @(
                Invoke-PleaseWorkTask `
                    -Name build `
                    -Snapshot $Snapshot `
                    -Arguments @{ Configuration = 'Release' } `
                    -Context @{ TaskFilePath = $TaskFile } `
                    -Result ([ref] $Result) `
                    -WorkingDirectory $TestDrive
            )

            $Output.Configuration | Should -Be 'Release'
            $Output.Count | Should -Be 1
            $Output.ModuleValue | Should -Be 'module-value'
            $Result.Succeeded | Should -BeTrue
            $Result.Output | Should -Be $Output
        }

        It 'does not carry task session-state changes into the next task runspace' {
            $FirstResult = $null
            $SecondResult = $null

            $FirstOutput = Invoke-PleaseWorkTask `
                -Name build `
                -Snapshot $Snapshot `
                -Arguments @{ Configuration = 'Debug' } `
                -Context @{} `
                -Result ([ref] $FirstResult) `
                -WorkingDirectory $TestDrive
            $SecondOutput = Invoke-PleaseWorkTask `
                -Name build `
                -Snapshot $Snapshot `
                -Arguments @{ Configuration = 'Debug' } `
                -Context @{} `
                -Result ([ref] $SecondResult) `
                -WorkingDirectory $TestDrive

            $FirstOutput.Count | Should -Be 1
            $SecondOutput.Count | Should -Be 1
            $Snapshot.Variables |
                Where-Object Name -eq SnapshotState |
                ForEach-Object { $_.Value.Count } |
                Should -Be 0
        }

        It 'returns output from before a task failure and preserves the task error' {
            $FailureTaskFile = Join-Path $TestDrive 'FailureTaskFile.ps1'
            @'
build: {
    'before failure'
    throw 'task failed'
}
'@ | Set-Content -LiteralPath $FailureTaskFile
            $FailureSnapshot = New-PleaseWorkTaskSnapshot -Path $FailureTaskFile
            $Result = $null

            {
                Invoke-PleaseWorkTask `
                    -Name build `
                    -Snapshot $FailureSnapshot `
                    -Context @{} `
                    -Result ([ref] $Result) `
                    -WorkingDirectory $TestDrive
            } | Should -Throw '*task failed*'

            $Result.Succeeded | Should -BeFalse
            $Result.ExitCode | Should -Be 1
            $Result.Error.Exception.Message | Should -Match 'task failed'
            $Result.Output | Should -Be @('before failure')
            $LASTEXITCODE | Should -Be 1
        }
    }
}
