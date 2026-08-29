# Runspace Error Handling Investigation

## Summary

PleaseWork needs to detect PowerShell errors and native command failures consistently in Windows
PowerShell 5.1 and PowerShell Core. A dedicated runspace provides enough information to implement
that behavior, but no single property represents task success.

Most command-level information belongs to the `PowerShell` pipeline attached to a runspace. The
runspace itself primarily reports the health and availability of its execution environment. A task
runner must therefore combine pipeline state, PowerShell error records, and explicit native exit
code capture.

The investigation used local probes in Windows PowerShell 5.1.19041.6456 and PowerShell 7.6.5.
Unless identified as an API contract, observations below describe those tested versions.

## Available signals

### Pipeline invocation state

`PowerShell.InvocationStateInfo` exposes the execution state of a pipeline and a `Reason` when a
state transition was caused by an error.

Terminating failures such as `throw`, parser errors, and errors promoted by
`$ErrorActionPreference = 'Stop'` produced:

* `InvocationStateInfo.State` equal to `Failed`.
* `InvocationStateInfo.Reason` containing the associated exception.
* `InvocationStateInfo.Reason.ErrorRecord` containing structured PowerShell error information when
  the exception exposes one.

The associated `ErrorRecord` can retain:

* `FullyQualifiedErrorId`
* `CategoryInfo`
* `TargetObject`
* `Exception`
* `InvocationInfo`
* `ScriptStackTrace`
* `PipelineIterationInfo`

This record is a better canonical PowerShell failure payload than an exception message alone.

### PowerShell streams

`PowerShell.Streams` exposes separate buffers for error, warning, verbose, debug, information, and
progress records. Success output is returned by `Invoke()` or written to a caller-provided output
collection.

Non-terminating errors produced a `Completed` pipeline with one or more records in
`PowerShell.Streams.Error`. Terminating failures generally produced a `Failed` pipeline whose
error was available through `InvocationStateInfo.Reason.ErrorRecord`, while the pipeline error
stream remained empty.

Consequently, checking only the error stream misses terminating failures, and checking only the
invocation state misses non-terminating errors.

### Runspace state

`Runspace.RunspaceStateInfo` reports the lifecycle of the runspace itself. A terminating pipeline
failure left the tested runspace `Opened` and `Available`, and the same runspace successfully ran a
subsequent pipeline.

A failed task is therefore not necessarily a failed runspace. Runspace state is useful for
detecting infrastructure failures, but it is not a task result.

### Native command status

PowerShell reports a native command's status through `$LASTEXITCODE`. The probes produced a
`Completed` pipeline for both exit code 0 and exit code 7. A nonzero native exit did not populate
`InvocationStateInfo.Reason` and did not necessarily add an error record.

PleaseWork must capture `$LASTEXITCODE` explicitly inside the task's runspace. It should reset the
value at the start of each task and evaluate the final value according to the task's native command
policy.

`$?` should not be the cross-version source of truth. In the probes, a native process that wrote to
stderr and exited 0 left `$?` false in Windows PowerShell 5.1 but true in PowerShell 7.6.

## Observed outcomes

| Condition | Pipeline state | Invocation reason | Error stream | Required task signal |
| --- | --- | --- | --- | --- |
| Successful script | `Completed` | None | Empty | None |
| Non-terminating cmdlet error | `Completed` | None | `ErrorRecord` | Error stream |
| Error promoted with `Stop` | `Failed` | Exception and `ErrorRecord` | Usually empty | Invocation reason |
| `throw` or parser error | `Failed` | Exception and `ErrorRecord` | Usually empty | Invocation reason |
| Native exit 0 | `Completed` | None | Usually empty | `$LASTEXITCODE` |
| Native exit 7 | `Completed` | None | Usually empty | `$LASTEXITCODE` |
| Native stderr with exit 0 | `Completed` | None | Version-sensitive | `$LASTEXITCODE` |

## Signals that are not sufficient

### `PowerShell.HadErrors`

`HadErrors` indicates that some error occurred while the pipeline executed, but it does not define
the final task outcome. It remained true after a native command exited 7 even when a later native
command exited 0. It was also true when a process wrote to stderr and exited 0.

This makes it useful as diagnostic metadata, but not as the authoritative success condition.

### The `$Error` automatic variable

`$Error` is cumulative session state. It can contain records from earlier operations in a reused
runspace and is affected by error preferences such as `Ignore`. The pipeline error stream and
invocation reason provide a clearer boundary for one execution.

### Native stderr

Native applications may use stderr for warnings, progress, or diagnostics while still returning
exit code 0. Stderr should be captured and presented, but it should not automatically imply task
failure. Exit-code policy must remain separate.

## Asynchronous observation

Both tested engines support:

* `PowerShell.BeginInvoke()` and `EndInvoke()`.
* `PowerShell.InvocationStateChanged` events.
* `DataAdded` events on error and other stream collections.
* Caller-provided output collections with `DataAdded` events.
* `PowerShell.Stop()` for cancellation.

These APIs permit live output forwarding, timeout enforcement, cancellation, and retention of
partial output. Events from separate streams do not inherently establish one total ordering across
all streams. If exact cross-stream ordering becomes a requirement, the producer must attach a
shared sequence or timestamp before records cross the boundary.

## Implications for PleaseWork

PleaseWork should keep task semantics separate from pipeline transport:

1. Set `$ErrorActionPreference = 'Stop'` in the task invocation scope so ordinary PowerShell errors
   become terminating task failures.
2. Reset and capture `$LASTEXITCODE` inside the task runspace for Desktop/Core-compatible native
   command handling.
3. Treat `InvocationStateInfo.Reason.ErrorRecord` as the primary terminating PowerShell failure.
4. Inspect `PowerShell.Streams.Error` for non-terminating errors that were intentionally allowed to
   continue.
5. Use `RunspaceStateInfo` only to diagnose execution-environment failures.
6. Preserve output and auxiliary streams independently from the final task result.
7. Record `HadErrors` as diagnostic information rather than using it as the success predicate.

`Invoke-PleaseWorkTask` already owns task-level error and native exit-code handling.
`Invoke-PleaseWorkInRunspace` owns the outer pipeline and runspace lifecycle. This separation is
appropriate. The outer layer can preserve richer terminating-error metadata by forwarding the
reason's `ErrorRecord`, when available, rather than reducing it to an exception message.

A useful task result contract would include the task name, outcome, nullable native exit code,
PowerShell error records, output, auxiliary streams, pipeline state, and timing information. The
outcome should be computed from explicit policy rather than inferred from one runtime property.

## Runspaces versus child processes

Starting a child process for each command provides stronger isolation and a simple process exit
code, stdout, and stderr contract. It does not solve PowerShell cmdlet error handling, and it loses
shared PowerShell scope and live structured objects.

A dedicated runspace pipeline per task is therefore a reasonable default model for PleaseWork. A
native-command helper can provide explicit process execution policy where required. Separate child
processes remain useful for hard isolation, selecting a different PowerShell edition, or reliably
terminating an entire process tree.

## References

* [PowerShell.InvocationStateInfo](https://learn.microsoft.com/dotnet/api/system.management.automation.powershell.invocationstateinfo)
* [PSInvocationStateInfo](https://learn.microsoft.com/dotnet/api/system.management.automation.psinvocationstateinfo)
* [PowerShell.Streams](https://learn.microsoft.com/dotnet/api/system.management.automation.powershell.streams)
* [ErrorRecord](https://learn.microsoft.com/dotnet/api/system.management.automation.errorrecord)
* [Runspace](https://learn.microsoft.com/dotnet/api/system.management.automation.runspaces.runspace)
* [PowerShell.BeginInvoke](https://learn.microsoft.com/dotnet/api/system.management.automation.powershell.begininvoke)
* [about_Automatic_Variables](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_automatic_variables)
* [about_Preference_Variables](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_preference_variables)
