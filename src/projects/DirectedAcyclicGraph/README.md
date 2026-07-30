# Pretty Please

A small, sequential PowerShell task runner with makefile-like task declarations.

```powershell
. ./DirectedAcyclicGraph.ps1

please              # Finds TaskFile.ps1 and runs its first declared task
please start
please build
please -List        # Lists tasks without running them
please build -WhatIf
please test -TaskFile ./AnotherTaskFile.ps1
```

A TaskFile declares tasks as `name: dependencies { body }`. Dependencies are optional:

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

Task declarations must be top-level statements. Each task name and its dependencies must be bare
words, and each declaration must end with a scriptblock body. Commands that resemble declarations
inside a task body are not treated as additional tasks.

When `-TaskFile` is omitted, Pretty Please searches the current directory and then each parent
directory for `TaskFile.ps1`. Task bodies run from the directory containing that file, so relative
paths remain stable regardless of where `please` was invoked. The caller's original location is
restored after execution, including when a task fails.

Task bodies can use `$TaskFilePath` for the resolved file path and `$TaskFileRoot` for its directory:

```powershell
inspect: {
    Write-Output "Running $TaskFilePath from $TaskFileRoot"
}
```

Only the requested task and its transitive dependencies run. Dependencies execute sequentially,
before their dependents, and shared dependencies run once. The runner stops on terminating errors.
Native process exit codes are not converted into errors; the final native command's exit code remains
available through `$LASTEXITCODE`.

## Future parallel execution

Parallel execution will require an explicit result for each task rather than relying on one shared
`$LASTEXITCODE`. Each worker runspace has its own `$LASTEXITCODE`, and completion order does not
provide a meaningful single "last" task when several tasks run concurrently. `$LASTEXITCODE` can
also retain the value from an earlier native command when a task does not invoke a native process.

Before invoking a task, its worker should initialize the native exit status to success. When the task
finishes, the worker should capture a result containing at least:

```text
TaskName, Succeeded, ExitCode, Error, StartedAt, FinishedAt
```

The last native command executed by that task determines its native exit status. A nonzero status or
a terminating PowerShell error fails that task. On failure, the scheduler should stop admitting new
work, never schedule the failed task's dependents, and request cancellation of tasks already running.
Already-running tasks may still produce their own results before cancellation completes.

The runner's overall outcome is therefore aggregate: it fails when any task fails, but it does not
pretend that one worker's native exit code is the canonical batch exit code. The exact task exit code
remains available in that task's result and can be included in verbose output. A command-line wrapper
can map aggregate success or failure to a conventional process exit code such as `0` or `1`.
