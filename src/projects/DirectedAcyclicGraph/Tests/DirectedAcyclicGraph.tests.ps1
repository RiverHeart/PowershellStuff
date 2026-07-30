$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/../DirectedAcyclicGraph.ps1"
}

Describe 'Invoke-PrettyPlease' {
    BeforeEach {
        $global:PrettyPleaseLog = [System.Collections.Generic.List[string]]::new()
    }

    AfterEach {
        Remove-Variable -Name PrettyPleaseLog -Scope Global -ErrorAction SilentlyContinue
    }

    It 'runs the first declared task by default' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
first: { $global:PrettyPleaseLog.Add('first') }
second: { $global:PrettyPleaseLog.Add('second') }
'@ | Set-Content -LiteralPath $TaskFile

        Invoke-PrettyPlease -TaskFile $TaskFile

        $global:PrettyPleaseLog | Should -Be @('first')
    }

    It 'runs transitive dependencies before the requested task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
lint: { $global:PrettyPleaseLog.Add('lint') }
test: lint { $global:PrettyPleaseLog.Add('test') }
build: test { $global:PrettyPleaseLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        please build -TaskFile $TaskFile

        $global:PrettyPleaseLog | Should -Be @('lint', 'test', 'build')
    }

    It 'runs a shared dependency only once' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
restore: { $global:PrettyPleaseLog.Add('restore') }
lint: restore { $global:PrettyPleaseLog.Add('lint') }
test: restore { $global:PrettyPleaseLog.Add('test') }
build: lint test { $global:PrettyPleaseLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        please build -TaskFile $TaskFile

        $global:PrettyPleaseLog | Should -Be @('restore', 'lint', 'test', 'build')
    }

    It 'rejects a missing dependency before running any task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
build: missing { $global:PrettyPleaseLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        { please build -TaskFile $TaskFile } | Should -Throw "Task 'missing' is not defined."
        $global:PrettyPleaseLog.Count | Should -Be 0
    }

    It 'rejects a dependency cycle before running any task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
first: second { $global:PrettyPleaseLog.Add('first') }
second: first { $global:PrettyPleaseLog.Add('second') }
'@ | Set-Content -LiteralPath $TaskFile

        { please first -TaskFile $TaskFile } | Should -Throw "Task dependency cycle detected for 'first'."
        $global:PrettyPleaseLog.Count | Should -Be 0
    }

    It 'stops when a task throws a terminating error' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
test: {
    $global:PrettyPleaseLog.Add('test')
    throw 'test failed'
}
build: test { $global:PrettyPleaseLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        { please build -TaskFile $TaskFile } | Should -Throw 'test failed'
        $global:PrettyPleaseLog | Should -Be @('test')
    }

    It 'fails a task when its final native process exits nonzero' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        $PowerShellPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        @'
native: {
    $global:PrettyPleaseLog.Add('native')
    & $global:PrettyPleasePowerShellPath -NoProfile -Command 'exit 7'
}
build: native { $global:PrettyPleaseLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile
        $global:PrettyPleasePowerShellPath = $PowerShellPath

        { please build -TaskFile $TaskFile } | Should -Throw "Task 'native' failed with exit code 7."

        $LASTEXITCODE | Should -Be 7
        $global:PrettyPleaseLog | Should -Be @('native')
        Remove-Variable -Name PrettyPleasePowerShellPath -Scope Global
    }

    It 'uses the last native exit code rather than failing on an intermediate code' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        $PowerShellPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        @'
probe: {
    & $global:PrettyPleasePowerShellPath -NoProfile -Command 'exit 7'
    & $global:PrettyPleasePowerShellPath -NoProfile -Command 'exit 0'
    $global:PrettyPleaseLog.Add('probe')
}
build: probe { $global:PrettyPleaseLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile
        $global:PrettyPleasePowerShellPath = $PowerShellPath

        please build -TaskFile $TaskFile

        $global:PrettyPleaseLog | Should -Be @('probe', 'build')
        Remove-Variable -Name PrettyPleasePowerShellPath -Scope Global
    }

    It 'lists tasks in declaration order without executing them' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
start: build { $global:PrettyPleaseLog.Add('start') }
build: test { $global:PrettyPleaseLog.Add('build') }
test: { $global:PrettyPleaseLog.Add('test') }
'@ | Set-Content -LiteralPath $TaskFile

        $Tasks = @(please -List -TaskFile $TaskFile)

        $Tasks.Name | Should -Be @('start', 'build', 'test')
        $Tasks[0].Dependencies | Should -Be @('build')
        $Tasks[0].Default | Should -BeTrue
        $Tasks[1].Default | Should -BeFalse
        $global:PrettyPleaseLog.Count | Should -Be 0
    }

    It 'does not execute tasks under WhatIf' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
lint: { $global:PrettyPleaseLog.Add('lint') }
test: lint { $global:PrettyPleaseLog.Add('test') }
build: test { $global:PrettyPleaseLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        please build -TaskFile $TaskFile -WhatIf

        $global:PrettyPleaseLog.Count | Should -Be 0
    }

    It 'ignores task-like commands nested inside a task body when loading declarations' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
build: {
    nested: { 'not a declaration' }
}
'@ | Set-Content -LiteralPath $TaskFile

        $TaskSet = Read-TaskFile -Path $TaskFile

        $TaskSet.TaskNames | Should -Be @('build')
    }

    It 'rejects a declaration without a body scriptblock' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        'build: test' | Set-Content -LiteralPath $TaskFile

        { Read-TaskFile -Path $TaskFile } |
            Should -Throw "Task 'build' must end with a scriptblock body."
    }

    It 'rejects quoted dependency names' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        "build: 'test' { 'build' }" | Set-Content -LiteralPath $TaskFile

        { Read-TaskFile -Path $TaskFile } |
            Should -Throw "Dependencies for task 'build' must be bare task names."
    }

    It 'rejects non-task top-level statements' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
Write-Output 'loading'
build: { 'build' }
'@ | Set-Content -LiteralPath $TaskFile

        { Read-TaskFile -Path $TaskFile } |
            Should -Throw 'TaskFiles may contain only top-level task declarations.'
    }

    It 'discovers a TaskFile in a parent directory' {
        $ProjectRoot = Join-Path $TestDrive 'project'
        $NestedDirectory = Join-Path $ProjectRoot 'src/deep'
        $null = New-Item -ItemType Directory -Path $NestedDirectory -Force
        @'
build: { $global:PrettyPleaseLog.Add('build') }
'@ | Set-Content -LiteralPath (Join-Path $ProjectRoot 'TaskFile.ps1')
        $OriginalLocation = Get-Location

        try {
            Set-Location $NestedDirectory
            please build
        } finally {
            Set-Location $OriginalLocation
        }

        $global:PrettyPleaseLog | Should -Be @('build')
    }

    It 'runs tasks from the TaskFile directory and exposes its paths' {
        $ProjectRoot = Join-Path $TestDrive 'project'
        $NestedDirectory = Join-Path $ProjectRoot 'src'
        $null = New-Item -ItemType Directory -Path $NestedDirectory -Force
        $TaskFile = Join-Path $ProjectRoot 'TaskFile.ps1'
        @'
inspect: {
    $global:PrettyPleaseWorkingDirectory = $PWD.ProviderPath
    $global:PrettyPleaseTaskFilePath = $TaskFilePath
    $global:PrettyPleaseTaskFileRoot = $TaskFileRoot
}
'@ | Set-Content -LiteralPath $TaskFile
        $OriginalLocation = Get-Location

        try {
            Set-Location $NestedDirectory
            please inspect
        } finally {
            Set-Location $OriginalLocation
        }

        $global:PrettyPleaseWorkingDirectory | Should -Be $ProjectRoot
        $global:PrettyPleaseTaskFilePath | Should -Be $TaskFile
        $global:PrettyPleaseTaskFileRoot | Should -Be $ProjectRoot
        Remove-Variable -Name PrettyPleaseWorkingDirectory -Scope Global
        Remove-Variable -Name PrettyPleaseTaskFilePath -Scope Global
        Remove-Variable -Name PrettyPleaseTaskFileRoot -Scope Global
    }

    It 'restores the caller location after successful execution' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
move: { Set-Location $env:TEMP }
'@ | Set-Content -LiteralPath $TaskFile
        $OriginalLocation = Get-Location

        please move -TaskFile $TaskFile

        (Get-Location).Path | Should -Be $OriginalLocation.Path
    }

    It 'restores the caller location after a task fails' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
fail: {
    Set-Location $env:TEMP
    throw 'task failed'
}
'@ | Set-Content -LiteralPath $TaskFile
        $OriginalLocation = Get-Location

        { please fail -TaskFile $TaskFile } | Should -Throw 'task failed'

        (Get-Location).Path | Should -Be $OriginalLocation.Path
    }
}

Describe 'Invoke-PrettyPleaseTask' {
    It 'injects task context and records a successful result without mixing it into output' {
        $Context = @{
            TaskFilePath = 'C:\project\TaskFile.ps1'
            TaskFileRoot = 'C:\project'
        }
        $Result = $null

        $Output = @(Invoke-PrettyPleaseTask `
            -Name inspect `
            -ScriptBlock { "$TaskFilePath|$TaskFileRoot"; 'task output' } `
            -Context $Context `
            -Result ([ref] $Result))

        $Output | Should -Be @(
            'C:\project\TaskFile.ps1|C:\project'
            'task output'
        )
        $Result.TaskName | Should -Be 'inspect'
        $Result.Succeeded | Should -BeTrue
        $Result.ExitCode | Should -Be 0
        $Result.Error | Should -BeNullOrEmpty
        $Result.StartedAt | Should -BeOfType ([datetime])
        $Result.FinishedAt | Should -BeOfType ([datetime])
        $Result.Duration | Should -BeOfType ([timespan])
    }

    It 'resets stale native status before invoking a task with no native commands' {
        $global:LASTEXITCODE = 23
        $Result = $null

        Invoke-PrettyPleaseTask `
            -Name powershellOnly `
            -ScriptBlock { Write-Output 'done' } `
            -Context @{} `
            -Result ([ref] $Result)

        $Result.Succeeded | Should -BeTrue
        $Result.ExitCode | Should -Be 0
        $LASTEXITCODE | Should -Be 0
    }

    It 'records a terminating error before rethrowing it' {
        $Result = $null

        { Invoke-PrettyPleaseTask `
            -Name broken `
            -ScriptBlock { throw 'broken task' } `
            -Context @{} `
            -Result ([ref] $Result) } | Should -Throw 'broken task'

        $Result.TaskName | Should -Be 'broken'
        $Result.Succeeded | Should -BeFalse
        $Result.ExitCode | Should -Be 0
        $Result.Error.Exception.Message | Should -Match 'broken task'
    }
}
