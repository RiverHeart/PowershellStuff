# PSScriptAnalyzer auto-loading in TaskFile tasks

## Summary

When a PleaseWork task invokes `Invoke-ScriptAnalyzer` from a clean PowerShell process,
PSScriptAnalyzer 1.25.0 can fail while it is being auto-loaded:

```text
The term 'Get-Command' is not recognized as a name of a cmdlet, function,
script file, or executable program.
```

The reported location is typically the exception rethrow in
`src/Private/Invoke-PleaseWorkTask.ps1`, rather than the code that called `Get-Command`.
This makes the failure initially appear to originate in PleaseWork's task wrapper.

The same task may work in the VS Code PowerShell extension because the extension has already
loaded PSScriptAnalyzer. In that environment, PowerShell does not exercise the failing auto-load
path.

## Affected invocation

PleaseWork binds TaskFile task bodies to a dynamic module so that TaskFile variables and functions
remain available after the TaskFile has been read. A module-bound task is invoked through the
following branch:

```powershell
if ($null -ne $ScriptBlock.Module) {
    & $ScriptBlock.Module $TaskInvoker $ScriptBlock $Context $Arguments
} else {
    & $TaskInvoker $ScriptBlock $Context $Arguments
}
```

The first branch executes `$TaskInvoker` in the TaskFile module's session state. The task body then
calls `Invoke-ScriptAnalyzer`. If PSScriptAnalyzer has not been imported, command discovery attempts
to auto-load it while this nested, module-bound invocation is active.

## Source of `Get-Command`

The failing `Get-Command` call is not present in the lint task or its normal PleaseWork execution
path. It comes from the installed PSScriptAnalyzer module itself.

PSScriptAnalyzer 1.25.0 contains this import-time check near line 36 of
`PSScriptAnalyzer.psm1`:

```powershell
if (Get-Command Register-ArgumentCompleter -ErrorAction Ignore) {
    # Register PSScriptAnalyzer argument completers.
}
```

The observed failure occurs while PowerShell auto-loads PSScriptAnalyzer from the module-bound task
invocation. At that point, the import-time check cannot resolve `Get-Command`.

This is a session-state interaction rather than evidence that PleaseWork deliberately removes
`Get-Command`:

- `Get-Command` is available when queried directly inside the TaskFile module.
- `Invoke-ScriptAnalyzer` works inside that module after PSScriptAnalyzer is explicitly imported.
- A plain dynamic module can auto-load PSScriptAnalyzer successfully.
- The failure has been reproduced in a clean `pwsh -NoProfile` process through the complete
  PleaseWork task invocation.

The trigger is therefore narrower than dynamic modules in general. It involves PSScriptAnalyzer's
import-time code and PleaseWork's nested invocation of a scriptblock bound to the TaskFile module.

## Why VS Code can hide the issue

The PowerShell extension commonly loads PSScriptAnalyzer to provide editor diagnostics. Running a
lint task in that session reuses the loaded module, so its import-time `Get-Command` check does not
run again.

A separate shell starts without that module state. Its first call to `Invoke-ScriptAnalyzer` causes
auto-loading and exposes the failure.

The two environments can be compared with:

```powershell
Get-Module PSScriptAnalyzer
Get-Module PSScriptAnalyzer -ListAvailable |
    Select-Object Name, Version, Path
```

## Dedicated runspace experiment

PleaseWork has an opt-in `-Runspace` prototype that imports the module, dot-sources the TaskFile,
registers its tasks, and invokes the complete task plan in a fresh runspace. The runspace itself is
the TaskFile's durable script scope, so task bodies are not bound to the dynamic module created by
`Read-TaskFile`.

This direct-loading design preserves dynamic task parameters, task output and errors, injected task
context, and persistent TaskFile `$script:` state. It also fixes the cold PSScriptAnalyzer auto-load
failure. In a clean `pwsh -NoProfile` process, `please lint -Runspace` reaches normal script analysis
without pre-importing PSScriptAnalyzer. The lint task may still throw `PSScriptAnalyzer found
issues.` when findings exist; that is its intended behavior.

Wrapping the old dynamic-module execution in a runspace did not fix the defect. The relevant change
was making TaskFile registration and task invocation occur in the runspace's script scope.

## Workaround for standard execution

Import PSScriptAnalyzer before PleaseWork enters the module-bound task invocation. For example, an
entrypoint script can use:

```powershell
Import-Module PSScriptAnalyzer -ErrorAction Stop
Import-Module PleaseWork -Force

please lint
```

Pre-importing PSScriptAnalyzer in a clean process removes the `Get-Command` error from the standard
dynamic-module execution path. The lint task then runs and reports normal analyzer findings. The
experimental `-Runspace` path does not require this workaround.

If the dependency must be loaded from the task body, importing it into global session state also
works:

```powershell
lint: changed('./**/*.ps1') {
    Import-Module PSScriptAnalyzer -Global -ErrorAction Stop

    $Results = $ChangedFiles |
        Invoke-ScriptAnalyzer -Settings "$GitRoot/PSScriptAnalyzerSettings.psd1"
    # Process results...
}
```

The entrypoint import is preferable when the entrypoint owns development-tool initialization. The
`-Global` form makes the task more self-contained, but it also mutates the caller's module state.

## Misleading error location

`Invoke-PleaseWorkTask` preserves the original error record in the task result and uses a bare
rethrow:

```powershell
$TaskError = $_
# Build the result...
throw
```

The bare rethrow preserves the active error record within the current runspace. The experimental
runspace boundary cannot preserve the same live `ErrorRecord`; it forwards the nested invocation's
failure reason to the caller instead.

## Reproduction

From `src/modules/PleaseWork`, use a process that has not already imported PSScriptAnalyzer:

```powershell
pwsh -NoProfile -NonInteractive -Command '
    Import-Module ./PleaseWork.psd1 -Force
    please lint
'
```

The observed failure reports `Get-Command` as unavailable and points at the wrapper rethrow.

Then pre-import PSScriptAnalyzer:

```powershell
pwsh -NoProfile -NonInteractive -Command '
    Import-Module ./PleaseWork.psd1 -Force
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    please lint
'
```

The second command proceeds into normal script analysis. It may still exit unsuccessfully when the
analyzer reports findings; that is separate from the module auto-loading failure.

## Diagnostic checklist

When this symptom appears:

1. Record the PowerShell and PSScriptAnalyzer versions.
2. Check whether `Get-Module PSScriptAnalyzer` returns a loaded module before the task starts.
3. Reproduce with `pwsh -NoProfile` to remove extension and profile initialization.
4. Explicitly import PSScriptAnalyzer before invoking `please` and compare the result.
5. Inspect the task result's preserved `Error` record when available, rather than relying only on
   the rethrown exception.

The issue should not be diagnosed as a missing PowerShell installation or a modified `PATH` unless
`Get-Command` also fails directly in the caller and TaskFile module session states.
