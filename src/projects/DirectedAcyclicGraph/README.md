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

Task names support tab completion. Completion parses declaration metadata without invoking the
TaskFile or any task bodies:

```powershell
please bu<Tab>                         # build
please -TaskFile ./Release.ps1 de<Tab> # deploy
```

When `-TaskFile` is already present on the command line, completion reads that file. Otherwise it
uses normal upward `TaskFile.ps1` discovery. A `-TaskFile` argument written later on the command line
is not yet bound during completion, so the discovered TaskFile is used for that case.

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

Pretty Please explicitly injects `$TaskFilePath` and `$TaskFileRoot` into each task invocation. Task
bodies can use them for the resolved file path and its directory:

```powershell
inspect: {
    Write-Output "Running $TaskFilePath from $TaskFileRoot"
}
```

Only the requested task and its transitive dependencies run. Dependencies execute sequentially,
before their dependents, and shared dependencies run once. The runner stops on terminating errors.

## Task results and exit codes

Each task produces an internal result containing:

```text
TaskName, Succeeded, ExitCode, Error, StartedAt, FinishedAt, Duration
```

Before each task, Pretty Please resets `$LASTEXITCODE` to `0`. A terminating PowerShell error fails
the task immediately. Otherwise, the last native command executed by the task determines its native
exit status after the scriptblock finishes. A nonzero final status fails the task and prevents its
dependents from running. Intermediate nonzero statuses do not stop the scriptblock, so task authors
can inspect and handle expected native failures using normal PowerShell control flow.

Task output remains in the normal output pipeline; result objects are kept separate for orchestration
and verbose diagnostics. The final native status remains available through `$LASTEXITCODE`.

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
