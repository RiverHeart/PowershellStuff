$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/../DirectedAcyclicGraph.ps1"
}

Describe 'Invoke-PleaseWork' {
    BeforeEach {
        $global:PleaseWorkLog = [System.Collections.Generic.List[string]]::new()
    }

    AfterEach {
        Remove-Variable -Name PleaseWorkLog -Scope Global -ErrorAction SilentlyContinue
    }

    It 'runs the first declared task by default' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
first: { $global:PleaseWorkLog.Add('first') }
second: { $global:PleaseWorkLog.Add('second') }
'@ | Set-Content -LiteralPath $TaskFile

        Invoke-PleaseWork -TaskFile $TaskFile

        $global:PleaseWorkLog | Should -Be @('first')
    }

    It 'runs transitive dependencies before the requested task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
lint: { $global:PleaseWorkLog.Add('lint') }
test: lint { $global:PleaseWorkLog.Add('test') }
build: test { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        please build -TaskFile $TaskFile

        $global:PleaseWorkLog | Should -Be @('lint', 'test', 'build')
    }

    It 'runs a shared dependency only once' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
restore: { $global:PleaseWorkLog.Add('restore') }
lint: restore { $global:PleaseWorkLog.Add('lint') }
test: restore { $global:PleaseWorkLog.Add('test') }
build: lint test { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        please build -TaskFile $TaskFile

        $global:PleaseWorkLog | Should -Be @('restore', 'lint', 'test', 'build')
    }

    It 'rejects a missing dependency before running any task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
build: missing { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        { please build -TaskFile $TaskFile } | Should -Throw "Task 'missing' is not defined."
        $global:PleaseWorkLog.Count | Should -Be 0
    }

    It 'rejects a dependency cycle before running any task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
first: second { $global:PleaseWorkLog.Add('first') }
second: first { $global:PleaseWorkLog.Add('second') }
'@ | Set-Content -LiteralPath $TaskFile

        { please first -TaskFile $TaskFile } | Should -Throw "Task dependency cycle detected for 'first'."
        $global:PleaseWorkLog.Count | Should -Be 0
    }

    It 'stops when a task throws a terminating error' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
test: {
    $global:PleaseWorkLog.Add('test')
    throw 'test failed'
}
build: test { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        { please build -TaskFile $TaskFile } | Should -Throw 'test failed'
        $global:PleaseWorkLog | Should -Be @('test')
    }

    It 'treats non-terminating PowerShell errors as task failures' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
test: {
    $global:PleaseWorkLog.Add('test')
    Write-Error 'test failed'
}
build: test { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        { please build -TaskFile $TaskFile } | Should -Throw 'test failed'
        $global:PleaseWorkLog | Should -Be @('test')
    }

    It 'fails a task when its final native process exits nonzero' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        $PowerShellPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        @'
native: {
    $global:PleaseWorkLog.Add('native')
    & $global:PleaseWorkPowerShellPath -NoProfile -Command 'exit 7'
}
build: native { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile
        $global:PleaseWorkPowerShellPath = $PowerShellPath

        { please build -TaskFile $TaskFile } | Should -Throw "Task 'native' failed with exit code 7."

        $LASTEXITCODE | Should -Be 7
        $global:PleaseWorkLog | Should -Be @('native')
        Remove-Variable -Name PleaseWorkPowerShellPath -Scope Global
    }

    It 'uses the last native exit code rather than failing on an intermediate code' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        $PowerShellPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        @'
probe: {
    & $global:PleaseWorkPowerShellPath -NoProfile -Command 'exit 7'
    & $global:PleaseWorkPowerShellPath -NoProfile -Command 'exit 0'
    $global:PleaseWorkLog.Add('probe')
}
build: probe { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile
        $global:PleaseWorkPowerShellPath = $PowerShellPath

        please build -TaskFile $TaskFile

        $global:PleaseWorkLog | Should -Be @('probe', 'build')
        Remove-Variable -Name PleaseWorkPowerShellPath -Scope Global
    }

    It 'lists tasks in declaration order without executing them' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
start: build { $global:PleaseWorkLog.Add('start') }
build: test { $global:PleaseWorkLog.Add('build') }
test: { $global:PleaseWorkLog.Add('test') }
'@ | Set-Content -LiteralPath $TaskFile

        $Tasks = @(please -List -TaskFile $TaskFile)

        $Tasks.Name | Should -Be @('start', 'build', 'test')
        $Tasks[0].Dependencies | Should -Be @('build')
        $Tasks[0].Default | Should -BeTrue
        $Tasks[1].Default | Should -BeFalse
        $global:PleaseWorkLog.Count | Should -Be 0
    }

    It 'does not execute tasks under WhatIf' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
lint: { $global:PleaseWorkLog.Add('lint') }
test: lint { $global:PleaseWorkLog.Add('test') }
build: test { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        please build -TaskFile $TaskFile -WhatIf

        $global:PleaseWorkLog.Count | Should -Be 0
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

    It 'allows non-task top-level statements' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
$Message = 'build'
function Get-Message {
    $Message
}
Write-Output 'loading'
build: { $global:PleaseWorkLog.Add((Get-Message)) }
'@ | Set-Content -LiteralPath $TaskFile

        $TaskSet = Read-TaskFile -Path $TaskFile
        $TaskSet.TaskNames | Should -Be @('build')

        please build -TaskFile $TaskFile

        $global:PleaseWorkLog | Should -Be @('build')
    }

    It 'does not register hashtable output as a task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
@{ Name = 'injected'; Dependencies = @(); ScriptBlock = { 'injected' } }
build: { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        $TaskSet = Read-TaskFile -Path $TaskFile

        $TaskSet.DefaultTask | Should -Be 'build'
        $TaskSet.TaskNames | Should -Be @('build')
    }

    It 'stops loading when TaskFile setup writes an error' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
Write-Error 'setup failed'
build: { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile
        $OriginalErrorActionPreference = $ErrorActionPreference

        try {
            $ErrorActionPreference = 'Continue'
            { Read-TaskFile -Path $TaskFile } | Should -Throw 'setup failed'
        } finally {
            $ErrorActionPreference = $OriginalErrorActionPreference
        }

        $global:PleaseWorkLog.Count | Should -Be 0
    }

    It 'returns one result per task with PassThru without mixing in task output' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
test: { 'test output' }
build: test { 'build output' }
'@ | Set-Content -LiteralPath $TaskFile

        $Results = @(please build -TaskFile $TaskFile -PassThru)

        $Results.Count | Should -Be 2
        $Results.TaskName | Should -Be @('test', 'build')
        $Results.Succeeded | Should -Be @($true, $true)
        $Results[0].Output | Should -Be @('test output')
        $Results[1].Output | Should -Be @('build output')
    }

    It 'continues to write task output without PassThru' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
build: { 'build output' }
'@ | Set-Content -LiteralPath $TaskFile

        $Output = @(please build -TaskFile $TaskFile)

        $Output | Should -Be @('build output')
    }

    It 'emits a failed task result with PassThru before rethrowing' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
test: {
    'before failure'
    throw 'test failed'
}
'@ | Set-Content -LiteralPath $TaskFile
        $Results = [System.Collections.Generic.List[object]]::new()

        {
            please test -TaskFile $TaskFile -PassThru |
                ForEach-Object { $Results.Add($_) }
        } | Should -Throw 'test failed'

        $Results.Count | Should -Be 1
        $Results[0].TaskName | Should -Be 'test'
        $Results[0].Succeeded | Should -BeFalse
        $Results[0].Error.Exception.Message | Should -Match 'test failed'
        $Results[0].Output | Should -BeNullOrEmpty
    }

    It 'discovers a TaskFile in a parent directory' {
        $ProjectRoot = Join-Path $TestDrive 'project'
        $NestedDirectory = Join-Path $ProjectRoot 'src/deep'
        $null = New-Item -ItemType Directory -Path $NestedDirectory -Force
        @'
build: { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath (Join-Path $ProjectRoot 'TaskFile.ps1')
        $OriginalLocation = Get-Location

        try {
            Set-Location $NestedDirectory
            please build
        } finally {
            Set-Location $OriginalLocation
        }

        $global:PleaseWorkLog | Should -Be @('build')
    }

    It 'runs tasks from the TaskFile directory and exposes its paths' {
        $ProjectRoot = Join-Path $TestDrive 'project'
        $NestedDirectory = Join-Path $ProjectRoot 'src'
        $null = New-Item -ItemType Directory -Path $NestedDirectory -Force
        $TaskFile = Join-Path $ProjectRoot 'TaskFile.ps1'
        @'
inspect: {
    $global:PleaseWorkWorkingDirectory = $PWD.ProviderPath
    $global:PleaseWorkTaskFilePath = $TaskFilePath
    $global:PleaseWorkTaskFileRoot = $TaskFileRoot
}
'@ | Set-Content -LiteralPath $TaskFile
        $OriginalLocation = Get-Location

        try {
            Set-Location $NestedDirectory
            please inspect
        } finally {
            Set-Location $OriginalLocation
        }

        $global:PleaseWorkWorkingDirectory | Should -Be $ProjectRoot
        $global:PleaseWorkTaskFilePath | Should -Be $TaskFile
        $global:PleaseWorkTaskFileRoot | Should -Be $ProjectRoot
        Remove-Variable -Name PleaseWorkWorkingDirectory -Scope Global
        Remove-Variable -Name PleaseWorkTaskFilePath -Scope Global
        Remove-Variable -Name PleaseWorkTaskFileRoot -Scope Global
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

Describe 'Invoke-PleaseWorkTask' {
    It 'injects task context and records a successful result without mixing it into output' {
        $Context = @{
            TaskFilePath = 'C:\project\TaskFile.ps1'
            TaskFileRoot = 'C:\project'
        }
        $Result = $null

        $Output = @(Invoke-PleaseWorkTask `
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

        Invoke-PleaseWorkTask `
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

        { Invoke-PleaseWorkTask `
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

Describe 'Task' {
    It 'registers a task without writing to the output pipeline' {
        $Registry = [System.Collections.Generic.List[hashtable]]::new()
        $Body = { 'build' }

        $Output = @(Task -Name build -Registry $Registry test lint $Body)

        $Output | Should -BeNullOrEmpty
        $Registry.Count | Should -Be 1
        $Registry[0].Name | Should -Be 'build'
        $Registry[0].Dependencies | Should -Be @('test', 'lint')
        $Registry[0].ScriptBlock | Should -Be $Body
    }

    It 'requires the final argument to be a scriptblock' {
        $Registry = [System.Collections.Generic.List[hashtable]]::new()

        { Task -Name build -Registry $Registry test } |
            Should -Throw 'The last argument must be a scriptblock.'
        $Registry | Should -BeNullOrEmpty
    }
}

Describe 'DirectedAcyclicGraph' {
    It 'rejects an edge that would create a cycle without changing the graph' {
        $Graph = [DirectedAcyclicGraph]::new()
        $Graph.AddNode('first')
        $Graph.AddNode('second')
        $Graph.AddEdge('first', 'second')

        { $Graph.AddEdge('second', 'first') } |
            Should -Throw "Adding edge from 'second' to 'first' would create a cycle."
        $Graph.GetTopologicalOrder() | Should -Be @('first', 'second')
    }

    It 'rejects edges containing an unknown node' {
        $Graph = [DirectedAcyclicGraph]::new()
        $Graph.AddNode('known')

        { $Graph.AddEdge('known', 'missing') } | Should -Throw "Node 'missing' does not exist."
    }

    It 'ignores duplicate edges' {
        $Graph = [DirectedAcyclicGraph]::new()
        $Graph.AddNode('first')
        $Graph.AddNode('second')

        $Graph.AddEdge('first', 'second')
        $Graph.AddEdge('first', 'second')

        $Graph.GetOutgoingEdges('first') | Should -Be @('second')
    }

    It 'returns a copy of outgoing edges' {
        $Graph = [DirectedAcyclicGraph]::new()
        $Graph.AddNode('first')
        $Graph.AddNode('second')
        $Graph.AddEdge('first', 'second')

        $Edges = $Graph.GetOutgoingEdges('first')
        $Edges[0] = 'changed'

        $Graph.GetOutgoingEdges('first') | Should -Be @('second')
    }
}

Describe 'Get-TaskFileDeclaration' {
    It 'returns ordered task metadata without executing task bodies' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
build: test lint { $global:PleaseWorkDeclarationExecuted = $true }
test: { 'test' }
lint: { 'lint' }
'@ | Set-Content -LiteralPath $TaskFile

        $Declarations = @(Get-TaskFileDeclaration -Path $TaskFile)

        $Declarations.Name | Should -Be @('build', 'test', 'lint')
        $Declarations[0].Dependencies | Should -Be @('test', 'lint')
        Get-Variable -Name PleaseWorkDeclarationExecuted -Scope Global -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }
}

Describe 'Invoke-PleaseWork argument completion' {
    It 'completes task names from a discovered parent TaskFile' {
        $ProjectRoot = Join-Path $TestDrive 'project'
        $NestedDirectory = Join-Path $ProjectRoot 'src/deep'
        $null = New-Item -ItemType Directory -Path $NestedDirectory -Force
        @'
build: { 'build' }
bundle: { 'bundle' }
test: { 'test' }
'@ | Set-Content -LiteralPath (Join-Path $ProjectRoot 'TaskFile.ps1')
        $OriginalLocation = Get-Location

        try {
            Set-Location $NestedDirectory
            $Completion = TabExpansion2 -InputScript 'please bu' -CursorColumn 9
        } finally {
            Set-Location $OriginalLocation
        }

        $Completion.CompletionMatches.CompletionText | Should -Be @('build', 'bundle')
    }

    It 'completes task names from an already-bound TaskFile' {
        $TaskFile = Join-Path $TestDrive 'AlternateTasks.ps1'
        @'
deploy: { 'deploy' }
destroy: { 'destroy' }
test: { 'test' }
'@ | Set-Content -LiteralPath $TaskFile
        $InputScript = "please -TaskFile '$TaskFile' de"

        $Completion = TabExpansion2 -InputScript $InputScript -CursorColumn $InputScript.Length

        $Completion.CompletionMatches.CompletionText | Should -Be @('deploy', 'destroy')
    }
}
