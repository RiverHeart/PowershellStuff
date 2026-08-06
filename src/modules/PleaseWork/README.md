# Please Work


```
"Life is not so short but that there is always time enough for courtesy."  
     — Ralph Waldo Emerson
```
\
\
Please Work is a small PowerShell task runner with makefile-like task declarations.

Tasks are defined as `name: dependencies { body }`. Dependencies are optional:

**taskfile.ps1**
```powershell
lint: {
    Invoke-ScriptAnalyzer -Path ./src
}

test: lint {
    Invoke-Pester
}

build: test {
    dotnet build
}
```

Invocation of the taskfile is about what you'd expect.

```powershell
Import-Module ./PleaseWork.psd1

please              # Run the default task
please build        # Run a specific task
please -List        # Lists tasks without running them
please test -TaskFile ./AnotherTaskFile.ps1  # Run tasks in a specific taskfile
```

Task names support tab completion. Completion parses declaration metadata without invoking the
TaskFile or any task bodies:

```powershell
please bu<Tab>                         # build
please -TaskFile ./Release.ps1 de<Tab> # deploy
```

Task declarations must be top-level statements. Each task name and its dependencies must be bare
words, and each declaration must end with a scriptblock body. Commands that resemble declarations
inside a task body are not treated as additional tasks. Task names are case-insensitive and must be
unique, so declarations such as `FOO:` and `foo:` cannot appear in the same TaskFile.

When `-TaskFile` is omitted, PleaseWork searches the current directory and then each parent
directory for `TaskFile.ps1`. Each task starts from the directory containing that file, so relative
paths remain stable even if an earlier task changes location. The caller's original location is
restored after execution, including when a task fails.

PleaseWork explicitly injects `$TaskFilePath` and `$TaskFileRoot` into each task invocation. Task
bodies can use them for the resolved file path and its directory:

```powershell
inspect: {
    Write-Output "Running $TaskFilePath from $TaskFileRoot"
}
```

Only the requested task and its transitive dependencies run. Dependencies execute sequentially,
before their dependents, and shared dependencies run once. Task declarations register through
private TaskFile state, so other output produced while loading a TaskFile is never interpreted as a
task. PowerShell errors in top-level TaskFile setup code stop loading immediately.

`-WhatIf` previews the complete resolved task plan without running it. Explicitly using `-Confirm`
asks once for that complete plan, so a dependent cannot run after its dependency was declined.

## Task results and exit codes

Each task produces an internal result containing:

```text
TaskName, Succeeded, ExitCode, Error, StartedAt, FinishedAt, Duration, Output
```

Before each task, PleaseWork resets `$LASTEXITCODE` to `0` and sets `$ErrorActionPreference` to
`Stop` for the task invocation. A PowerShell error therefore fails the task immediately. Otherwise,
the last native command executed by the task determines its native exit status after the scriptblock
finishes. A nonzero final status fails the task and prevents its dependents from running.
Intermediate nonzero statuses do not stop the scriptblock, so task authors can inspect and handle
expected native failures using normal PowerShell control flow.

On PowerShell 7, callers can set `$PSNativeCommandUseErrorActionPreference` to `$true` to make a
nonzero native exit code participate in PowerShell error handling. In that mode, the injected
`$ErrorActionPreference = 'Stop'` causes the task to stop at the first failing native command.
PleaseWork does not set this PowerShell 7-only preference so its default behavior remains compatible
with Windows PowerShell 5.1.

By default, task output remains in the normal output pipeline. With `-PassThru`, PleaseWork instead
returns one result object per executed task and stores each task's output in that result's `Output`
property. The final native status remains available through `$LASTEXITCODE`.


Tasks can use `changed()` filters containing literal Git pathspecs. A filtered task runs when a
matching file changed or when one of its task dependencies ran:

```powershell
$PleaseWorkConfig = @{
    BaseRef = $env:GIT_PREVIOUS_SUCCESSFUL_COMMIT
    HeadRef = if ($env:GIT_COMMIT) { $env:GIT_COMMIT } else { 'HEAD' }
}

test: changed('./Tests') {
    Invoke-Pester -Path $ChangedFiles
}

build: test changed('./Public', './Private') {
    & "$GitRoot/tools/Build-PSResource.ps1" -ProjectPath ./project.psd1
}
```

### Incremental Builds

PleaseWork does not persist the last successful commit itself meaning it can't support
incremental builds on its own. CI systems that track state can be used to set `$PleaseWorkConfig.BaseRef`
and `$PleaseWorkConfig.HeadRef` from their own build variables. For example, Jenkins' Git
plugin exposes `GIT_PREVIOUS_SUCCESSFUL_COMMIT` and `GIT_COMMIT`. PleaseWork recognizes those
variables as built-in fallbacks, so Jenkins commonly needs no explicit TaskFile configuration.

Explicit configuration takes precedence over recognized environment variables. On a first build,
or when no previous successful commit is available, PleaseWork tries the remote default branch and
otherwise runs filtered tasks conservatively.

Filtered task bodies receive `$ChangedFiles`, containing repository-relative files matching that
task's pathspecs. `$Changeset` exposes `Provider`, `Root`, `BaseRef`, `HeadRef`, `CompareRef`,
`Files`, and `Available`; `$Changeset.Files` contains the complete changeset. All task bodies receive
`$ChangedFiles`, which is empty for an unfiltered task or a task run only because its dependency ran.

## Future parallel execution

Parallel execution will extend the same result model into each worker rather than relying on one
shared `$LASTEXITCODE`. Each worker runspace has its own `$LASTEXITCODE`, and completion order does
not provide a meaningful single "last" task when several tasks run concurrently.

The last native command executed by that task determines its native exit status. A nonzero status or
a terminating PowerShell error fails that task. On failure, the scheduler should stop admitting new
work, never schedule the failed task's dependents, and request cancellation of tasks already running.
Already-running tasks may still produce their own results before cancellation completes.

The runner's overall outcome is therefore aggregate: it fails when any task fails, but it does not
pretend that one worker's native exit code is the canonical batch exit code. The exact task exit code
remains available in that task's result and can be included in verbose output. A command-line wrapper
can map aggregate success or failure to a conventional process exit code such as `0` or `1`.
