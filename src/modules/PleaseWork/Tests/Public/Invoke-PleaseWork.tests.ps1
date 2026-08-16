Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
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

    It 'binds and validates named parameters declared by the requested task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
build: {
    param (
        [Parameter(Mandatory)]
        [Alias('cfg')]
        [ValidateSet('Debug', 'Release')]
        [string] $Configuration,

        [switch] $Force
    )

    "$Configuration|$Force"
}
'@ | Set-Content -LiteralPath $TaskFile

    please build -TaskFile $TaskFile -cfg Release -Force |
            Should -Be 'Release|True'

        { please build -TaskFile $TaskFile -Configuration Invalid } |
            Should -Throw '*Cannot validate argument on parameter*Configuration*'
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

    It 'resolves task and dependency names without regard to case' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
lint: { $global:PleaseWorkLog.Add('lint') }
build: LINT { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile

        please BUILD -TaskFile $TaskFile

        $global:PleaseWorkLog | Should -Be @('lint', 'build')
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

    It 'skips a filtered task when no changed files match' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
    $PleaseConfig = @{ BaseRef = 'base' }
build: changed('./Public') { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile
        Mock Get-GitChangeset {
            [pscustomobject] @{
                Provider = 'Git'
                Root = 'C:\repo'
                BaseRef = 'base'
                HeadRef = 'head'
                CompareRef = 'base'
                HeadCommit = 'head'
                Files = @('README.md')
                Available = $true
            }
        }
        Mock Get-GitChangedPath { @() }

        please build -TaskFile $TaskFile

        $global:PleaseWorkLog.Count | Should -Be 0
    }

    It 'exposes matching files and changeset metadata to a filtered task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
    $PleaseConfig = @{ BaseRef = 'configured-base'; HeadRef = 'configured-head' }
build: changed('./Public') {
    $global:PleaseWorkLog.Add('build')
    $global:PleaseWorkChangedFiles = $ChangedFiles
    $global:PleaseWorkChangeset = $Changeset
}
'@ | Set-Content -LiteralPath $TaskFile
        Mock Get-GitChangeset {
            [pscustomobject] @{
                Provider = 'Git'
                Root = 'C:\repo'
                BaseRef = $BaseRef
                HeadRef = $HeadRef
                CompareRef = 'base'
                HeadCommit = 'head'
                Files = @('Public/One.ps1', 'README.md')
                Available = $true
            }
        }
        Mock Get-GitChangedPath { @('Public/One.ps1') }

        please build -TaskFile $TaskFile

        $global:PleaseWorkLog | Should -Be @('build')
        $global:PleaseWorkChangedFiles | Should -Be @(
            [System.IO.Path]::GetFullPath((Join-Path 'C:\repo' 'Public/One.ps1'))
        )
        $global:PleaseWorkChangeset.Files | Should -Be @('Public/One.ps1', 'README.md')
        $global:PleaseWorkChangeset.Provider | Should -Be 'Git'
        Should -Invoke Get-GitChangeset -Times 1 -Exactly -ParameterFilter {
            $BaseRef -eq 'configured-base' -and $HeadRef -eq 'configured-head'
        }
        Remove-Variable -Name PleaseWorkChangedFiles -Scope Global
        Remove-Variable -Name PleaseWorkChangeset -Scope Global
    }

    It 'runs an unmatched filtered task when one of its task dependencies ran' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
    $PleaseConfig = @{ BaseRef = 'base' }
test: changed('./Tests') { $global:PleaseWorkLog.Add('test') }
build: test changed('./Public') { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile
        Mock Get-GitChangeset {
            [pscustomobject] @{
                Provider = 'Git'
                Root = 'C:\repo'
                BaseRef = 'base'
                HeadRef = 'head'
                CompareRef = 'base'
                HeadCommit = 'head'
                Files = @('Tests/One.tests.ps1')
                Available = $true
            }
        }
        Mock Get-GitChangedPath {
            if ($PathSpec -contains './Tests') {
                return @('Tests/One.tests.ps1')
            }
            return @()
        }

        please build -TaskFile $TaskFile

        $global:PleaseWorkLog | Should -Be @('test', 'build')
    }

    It 'rejects a filtered task when no base ref is configured' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
build: changed('./Public') { $global:PleaseWorkLog.Add('build') }
'@ | Set-Content -LiteralPath $TaskFile
    Mock Get-GitChangeset { throw 'Get-GitChangeset should not be called.' }

        { please build -TaskFile $TaskFile } |
            Should -Throw 'Tasks using changed() require a non-empty $PleaseConfig.BaseRef.'
        $global:PleaseWorkLog.Count | Should -Be 0
        Should -Invoke Get-GitChangeset -Times 0 -Exactly
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
        @($Tasks | Where-Object { $null -ne $_.Description }).Count | Should -Be 0
        $global:PleaseWorkLog.Count | Should -Be 0
    }

    It 'lists descriptions from comment-based help only on the associated task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
<#
.DESCRIPTION
    Starts the build.
#>
start: build { 'start' }
build: { 'build' }
'@ | Set-Content -LiteralPath $TaskFile

        $Declarations = @(Get-TaskFileDeclaration -Path $TaskFile)

        $Declarations[0].Comments.Count | Should -Be 1
        $Declarations[0].Comments[0] | Should -Match 'Starts the build\.'
        $Declarations[0].Help | Should -BeOfType (
            [System.Management.Automation.Language.CommentHelpInfo]
        )
        $Declarations[0].Help.Description.Trim() | Should -Be 'Starts the build.'
        $Declarations[1].Comments | Should -BeNullOrEmpty
        $Declarations[1].Help | Should -BeNullOrEmpty

        $Tasks = @(please -List -TaskFile $TaskFile)
        $Tasks[0].Description | Should -Be 'Starts the build.'
        $Tasks[1].Description | Should -BeNullOrEmpty
    }

    It 'displays native help as task names and descriptions without executing tasks' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
<#
.DESCRIPTION
    Builds the project.
#>
build: { $global:PleaseWorkLog.Add('build') }
test: { $global:PleaseWorkLog.Add('test') }
'@ | Set-Content -LiteralPath $TaskFile

        $Output = @(please help -TaskFile $TaskFile)

        $Output | Should -Be @(
            'Available tasks:'
            '  build  Builds the project.'
            '  test'
        )
        $global:PleaseWorkLog.Count | Should -Be 0
    }

    It 'rejects a user task named help by default' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        "help: { 'custom help' }" | Set-Content -LiteralPath $TaskFile

        { please help -TaskFile $TaskFile } |
            Should -Throw "Task 'help' is reserved. Set `$PleaseConfig.OverrideHelp = `$true to override it."
    }

    It 'runs a user help task when PleaseConfig overrides native help' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
$PleaseConfig = @{ OverrideHelp = $true }
help: { 'custom help' }
build: { 'build' }
'@ | Set-Content -LiteralPath $TaskFile

        $Output = @(please help -TaskFile $TaskFile)

        $Output | Should -Be @('custom help')
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

    It 'rejects task declarations that differ only by case before loading the TaskFile' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
$global:PleaseWorkDuplicateTaskFileLoaded = $true
FOO: { 'first' }
foo: { 'second' }
'@ | Set-Content -LiteralPath $TaskFile

        { Read-TaskFile -Path $TaskFile } | Should -Throw "Task 'foo' is declared more than once."
        Get-Variable -Name PleaseWorkDuplicateTaskFileLoaded -Scope Global -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'rejects an empty task name' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        ': { ''body'' }' | Set-Content -LiteralPath $TaskFile

        { Read-TaskFile -Path $TaskFile } | Should -Throw 'Task names cannot be empty.'
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

    It 'requires script scope to mutate a top-level TaskFile variable across tasks' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
$Value = 'top-level'
changeLocal: {
    $Value = 'local-change'
    "local:$Value"
}
readAfterLocal: changeLocal { "after-local:$Value" }
changeScript: readAfterLocal {
    $script:Value = 'script-change'
    "script:$Value"
}
readAfterScript: changeScript { "after-script:$Value" }
'@ | Set-Content -LiteralPath $TaskFile

        $Output = @(please readAfterScript -TaskFile $TaskFile)

        $Output | Should -Be @(
            'local:local-change'
            'after-local:top-level'
            'script:script-change'
            'after-script:script-change'
        )
    }

    It 'runs the complete task plan in a dedicated runspace' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
$Value = 'initial'
prepare: {
    $script:Value = 'prepared'
    "prepare:$Value"
}
build: prepare {
    param ([string] $Configuration)
    "build:${Value}:$Configuration"
    "context:$(Split-Path -Leaf $TaskFilePath)"
    "module-bound:$($null -ne $MyInvocation.MyCommand.Module)"
}
'@ | Set-Content -LiteralPath $TaskFile

        $Output = @(please build -TaskFile $TaskFile -Configuration Release -Runspace)

        $Output | Should -Be @(
            'prepare:prepared'
            'build:prepared:Release'
            'context:TaskFile.ps1'
            'module-bound:False'
        )
    }

    It 'returns task output before rethrowing an error from a dedicated runspace' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
fail: {
    'before failure'
    throw 'runspace task failed'
}
'@ | Set-Content -LiteralPath $TaskFile
        $Output = [System.Collections.Generic.List[object]]::new()

        {
            please fail -TaskFile $TaskFile -Runspace |
                ForEach-Object { $Output.Add($_) }
        } | Should -Throw 'runspace task failed'

        $Output | Should -Be @('before failure')
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
        $Results[0].Output | Should -Be @('before failure')
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

    It 'resets the working directory before each task' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
move: { Set-Location $env:TEMP }
inspect: move { $PWD.ProviderPath }
'@ | Set-Content -LiteralPath $TaskFile

        $Output = please inspect -TaskFile $TaskFile

        $Output | Should -Be $TestDrive
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

    It 'completes native help when its prefix matches' {
        $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        "build: { 'build' }" | Set-Content -LiteralPath $TaskFile
        $InputScript = "please -TaskFile '$TaskFile' he"

        $Completion = TabExpansion2 -InputScript $InputScript -CursorColumn $InputScript.Length

        $Completion.CompletionMatches.CompletionText | Should -Be @('help')
    }
}

