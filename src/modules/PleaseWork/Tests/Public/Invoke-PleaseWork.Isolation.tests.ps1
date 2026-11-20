Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

Describe 'Invoke-PleaseWork session-state isolation' {
    BeforeAll {
        $TestTaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
$Value = 'initial'

prepare: {
    $script:Value = 'prepared'
    "prepare:$Value"
}

build: prepare {
    param ([string] $Configuration)
    "build:${Value}:$Configuration"
}
'@ | Set-Content -LiteralPath $TestTaskFile
    }

    It 'starts each task from the TaskFile snapshot' {
        $Output = @(please build -TaskFile $TestTaskFile -Configuration Release)

        $Output | Should -Be @(
            'prepare:prepared'
            'build:initial:Release'
        )
    }

    It 'returns structured task results without mixing task output' {
        $Results = @(please build -TaskFile $TestTaskFile -PassThru)

        $Results.TaskName | Should -Be @('prepare', 'build')
        $Results.Output[0] | Should -Be 'prepare:prepared'
        $Results.Output[1] | Should -Be 'build:initial:'
        $Results.Succeeded | Should -Be @($true, $true)
    }

    It 'does not inherit caller-only functions' {
        function global:Get-PleaseWorkCallerOnlyValue {
            'caller-value'
        }
        try {
            $CallerTaskFile = Join-Path $TestDrive 'CallerTaskFile.ps1'
            @'
build: {
    Get-Command Get-PleaseWorkCallerOnlyValue -ErrorAction Stop
}
'@ | Set-Content -LiteralPath $CallerTaskFile

            { please build -TaskFile $CallerTaskFile } |
                Should -Throw '*Get-PleaseWorkCallerOnlyValue*'
        } finally {
            Remove-Item Function:\global:Get-PleaseWorkCallerOnlyValue -ErrorAction Ignore
        }
    }

    It 'fails fast and returns output before a task error' {
        $FailureTaskFile = Join-Path $TestDrive 'FailureTaskFile.ps1'
        @'
test: {
    'before failure'
    throw 'isolated failure'
}
build: test {
    'dependent output'
}
'@ | Set-Content -LiteralPath $FailureTaskFile
        $Output = [System.Collections.Generic.List[object]]::new()

        {
            please build -TaskFile $FailureTaskFile |
                ForEach-Object { $Output.Add($_) }
        } | Should -Throw '*isolated failure*'

        $Output | Should -Be @('before failure')
    }

    It 'does not execute TaskFile setup for task listing' {
        $GlobalMarker = "PleaseWorkListMarker_$([guid]::NewGuid().ToString('N'))"
        $ListTaskFile = Join-Path $TestDrive 'ListTaskFile.ps1'
        @"
Set-Item Env:$GlobalMarker 'loaded'
build: { 'build' }
"@ | Set-Content -LiteralPath $ListTaskFile

        try {
            @(please -List -TaskFile $ListTaskFile).Name | Should -Be @('build')
            [Environment]::GetEnvironmentVariable($GlobalMarker) |
                Should -BeNullOrEmpty
        } finally {
            [Environment]::SetEnvironmentVariable($GlobalMarker, $null)
        }
    }

    It 'does not share PleaseConfig mutations or wrapper variables between tasks' {
        $ConfigTaskFile = Join-Path $TestDrive 'ConfigTaskFile.ps1'
        @'
$PleaseConfig = @{ Shared = 0 }
prepare: {
    $PleaseConfig.Shared = 9
    'prepare'
}
build: prepare {
    [pscustomobject] @{
        Shared = $PleaseConfig.Shared
        WrapperVisible = $null -ne (Get-Variable TaskConfig -ErrorAction Ignore)
    }
}
'@ | Set-Content -LiteralPath $ConfigTaskFile

        $Output = @(please build -TaskFile $ConfigTaskFile)

        $Output[0] | Should -Be 'prepare'
        $Output[1].Shared | Should -Be 0
        $Output[1].WrapperVisible | Should -BeFalse
    }

    It 'does not expose or mutate isolated invocation wrappers' {
    $WrapperTaskFile = Join-Path $TestDrive 'WrapperTaskFile.ps1'
    @'
build: {
    [pscustomobject] @{
    TaskScript = $null -ne (Get-Variable TaskScript -ErrorAction Ignore)
    TaskContext = $null -ne (Get-Variable TaskContext -ErrorAction Ignore)
    TaskArguments = $null -ne (Get-Variable TaskArguments -ErrorAction Ignore)
    }
}
'@ | Set-Content -LiteralPath $WrapperTaskFile
    $Context = @{ Marker = 'original' }

    $Output = please build -TaskFile $WrapperTaskFile

    $Output.TaskScript | Should -BeFalse
    $Output.TaskContext | Should -BeFalse
    $Output.TaskArguments | Should -BeFalse
    $Context.Marker | Should -Be 'original'
    }
}
