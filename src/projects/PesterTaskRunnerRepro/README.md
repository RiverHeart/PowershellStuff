# Pester Task-Runner Scope Reproduction

This project isolates a reported difference in Pester behavior when the same
test file runs directly versus inside a Please Work task. It is a reduced probe
for PowerShell module/session-state cleanup; it is not intended to assert that
Pester itself is defective.

## Reproduce

From the repository root, run the focused test directly:

```powershell
$TestPaths = @(
    (Resolve-Path `
        .\src\projects\PesterTaskRunnerRepro\Tests\ModuleCleanup.Tests.ps1).Path
    (Resolve-Path `
        .\src\projects\PesterTaskRunnerRepro\Tests\ModuleCleanupReference.Tests.ps1).Path
)
Import-Module Pester -MinimumVersion '5.0.0' -ErrorAction Stop
Invoke-Pester -Path $TestPaths -Output Detailed
```

Then run it in Please Work's normal task scope and dedicated runspace:

```powershell
Import-Module .\src\modules\PleaseWork\PleaseWork.psd1 -Force
pw test -TaskFile .\src\projects\PesterTaskRunnerRepro\TaskFile.ps1
pw test -TaskFile .\src\projects\PesterTaskRunnerRepro\TaskFile.ps1 -Runspace
```

Record the PowerShell and Pester versions when comparing another setup.

## What the test does

The test uses temporary modules with duplicate command names. It removes those
modules from a different module scope, then checks whether the removed commands
remain discoverable.

It contains two equivalent cleanup forms:

1. **Discovery form (`ModuleCleanup.Tests.ps1`):** resolve the modules again
   with `Get-Module -All` and pipe those results to `Remove-Module`.
2. **Reference form (`ModuleCleanupReference.Tests.ps1`):** create the dynamic
   wrapper in a child scope, retain the result of piping it through
   `Import-Module -PassThru` in a script-scoped variable, and pass those
   `PSModuleInfo` instances to `Remove-Module` in `AfterAll`.

The forms run in separate Pester containers so one cleanup path cannot alter the
session state observed by the other.

The significant sequence for each form is:

1. Import the first `RulePackageRules` module into the current test scope.
2. Create a dynamic module, import a second module with the same name and
   exported command into that dynamic module with `-Scope Local`, and then pipe
   the dynamic module to `Import-Module` so it is registered in the test scope.
3. Use Pester's `InModuleScope ScopeHarness` to remove both module instances.
4. Verify that neither module appears in `Get-Module -All`.
5. Verify that `Test-ReproRule` is no longer discoverable.

## Observed behavior

| Invocation | Result |
| --- | --- |
| `Invoke-Pester`, focused test directly | Passes |
| `pw test` in the normal task scope | Fails |
| `pw test -Runspace` | Passes |

This was reproduced with PowerShell 7.6.10 and Pester 5.7.1. The existing baseline
also records the same direct/task/runspace split on Windows PowerShell
5.1.19041.6456 with Pester 5.7.1.

Piping the `New-Module` result to `Import-Module` does not change this split.
Retaining the `PSModuleInfo` instances in script-scoped variables and removing
those exact instances in `AfterAll` also does not change it. In the normal task
scope, that form leaves zero modules registered but one retained command visible
through `Get-Command -All`, causing the reference container to fail teardown.
Creating the dynamic module inside a child scope with
`$script:foo = & { New-Module ... } | Import-Module -PassThru` preserves the same
result.

In the failing task-scoped run, the final module query is empty, but
`Get-Command Test-ReproRule` still returns the command imported from the first
module. Its source is `RulePackageRules` and its definition is the first
module's function body.

## Investigation notes

The evidence distinguishes module removal from command-table cleanup:

- `Get-Module -All` no longer reports either temporary module.
- The command remains discoverable only in the normal Please Work task scope.
- A breakpoint probe run in the normal task scope observed no modules and no
  commands immediately after cleanup, while the Pester assertion in its own
  nested scope still resolved the command.
- The dedicated Please Work runspace removes the mismatch.
- Importing the first temporary module with `Import-Module -Global` made the
  controlled reproduction pass under the normal task scope.

Normal Please Work execution binds TaskFile script blocks to a dynamic module and
invokes task bodies there. Pester's `InModuleScope` also binds the supplied
scriptblock to the target module's session state.

The precise formulation supported by this reproduction is:

> `Remove-Module` unregisters a module in the session state where removal occurs
> and runs its removal logic. It does not guarantee removal of every command
> exported into another nested session state. A surviving function can retain
> the original, now-unregistered `PSModuleInfo` through its bound script block.

This means the failure is not evidence that `Remove-Module` did nothing. The
module objects are removed from the module registry and their `OnRemove` logic
runs, but a command-table entry associated with another importing scope remains.

## CommandInfo module references

The retained command still has a non-null `CommandInfo.Module` property:

```powershell
$Command = Get-Command Test-ReproRule
$Command.Module       # RulePackageRules
$Command.Module.Name  # RulePackageRules
```

The returned object is the original `PSModuleInfo` instance: reference equality
with the instance returned by the first import was true. It retains its
`SessionState`, can resolve its own `Test-ReproRule`, and the stale command can
still execute and return `'first'`. At the same time, the module is no longer
present in `Get-Module -All`. It is therefore a live, detached module object
rather than a registered module.

Passing that detached object back to `Remove-Module` did not clear the command
from the failing scope:

```powershell
Remove-Module -ModuleInfo $Command.Module -Force
Get-Command Test-ReproRule # still returns the retained command
```

Removing the function directly from the scope where it remained visible did
clear it:

```powershell
Remove-Item -LiteralPath 'Function:Test-ReproRule' -Force
```

`CommandInfo.Module` is therefore useful for identifying an orphaned command's
source, but it is not by itself sufficient to remove that command-table entry.
Direct command removal should be treated as a narrow diagnostic or test cleanup
workaround because a command may be shadowed by another legitimate function
with the same name. Prefer isolation or explicit import ownership for normal
test-runner use.

## Mitigations

For stateful test suites, prefer an isolated process or Please Work's dedicated
runspace:

```powershell
pw test -TaskFile .\src\projects\PesterTaskRunnerRepro\TaskFile.ps1 -Runspace
```

When a test intentionally needs to import modules that another module scope will
remove, make the import ownership explicit. For this reproduction,
`Import-Module -Global` avoids the stale local command entry. That option should
be limited to tests that own and clean up the resulting global state.

Do not treat changing normal Please Work execution to global scope as a general
fix. Isolation preserves module and command state boundaries without changing
the semantics of unrelated TaskFiles.

