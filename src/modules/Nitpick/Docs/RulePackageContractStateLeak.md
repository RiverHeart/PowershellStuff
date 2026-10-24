# Rule Package Contract Test State Leak

The leak originates in the "pins a literal path" test's teardown, not in the
later test that reports it.

## Where It Occurs

In [RulePackages.Contracts.Tests.ps1](../Tests/RulePackages.Contracts.Tests.ps1),
the test named "pins a literal path despite a same-named module already being
loaded elsewhere" performs the following sequence:

1. Line 284 imports the **First** package into the test's scope.
2. `Find-Nitpick` acquires the same-named **Second** package through a dynamic
   module.
3. The `AfterEach` removal at line 99 runs **inside Nitpick's module scope**.

Immediately after that removal:

| Observation | Result |
|---|---|
| `Get-Module -All` lists either package instance | No |
| `Get-Command Test-ContractRule` finds the First package's command | **Yes** |
| The leftover command remains callable | **Yes** |

The later "loads supporting rule modules without initializing a
rule-modules-only parent" test, starting at line 328, merely detects that
leftover command. Its path points to the earlier test's **First** directory.

Line numbers describe the file at the time of the investigation.

## Why It Happens

The dynamic wrapper in
[Get-NitpickPackage.ps1](../Private/Get-NitpickPackage.ps1) (named
`Get-NitpickModulePackage.ps1` at the time of this investigation), starting
at line 50, does not explicitly suppress exports:

```powershell
New-Module -ReturnResult ... -ScriptBlock {
    param ($ModulePath)
    Import-Module -Name $ModulePath -Scope Local -PassThru -ErrorAction Stop
}
```

The snippet abbreviates arguments unrelated to the leak.

**`-ReturnResult` does not disable `New-Module`'s implicit function exports.**
The wrapper exposes the imported rule function inside Nitpick's scope,
attributed to the dynamic wrapper. That function shadows the First package's
command in the caller's scope.

PowerShell's removal implementation examines the **current session state's
visible function table**, matching functions by their module path. Inside
Nitpick, it sees the wrapper's function rather than the caller's First-package
function. Consequently, it removes the package entries from the module tables
without removing that caller-side function.

This explains the apparently contradictory diagnostics: **no loaded module,
but an exported command still exists**.

The relevant implementation is `RemoveModule` in PowerShell's
[ModuleCmdletBase.cs](https://github.com/PowerShell/PowerShell/blob/v7.6.0/src/System.Management.Automation/engine/Modules/ModuleCmdletBase.cs#L5021).
Function removal uses `Context.EngineSessionState` and its function table,
while module-table removal subsequently traverses the session-state module
tables and removes the global module entry.

## Verification

The investigation used PowerShell 7.6.6 and Pester 5.7.1.

- Original targeted run: **34 passed, 1 failed, 12 skipped**.
- Standalone reproduction without Pester: the same leak occurred.
- Temporary caller-scope cleanup injected through a breakpoint:
  **35 passed, 0 failed, 12 skipped**.
- Standalone reproduction with explicit empty wrapper exports: no shadowing
  and no leftover command.

The targeted test file was run through the repository test runner:

```powershell
.\tools\Invoke-Test.ps1 -Suite Nitpick -Path Tests\RulePackages.Contracts.Tests.ps1
```

## Corrective Directions

The two corrective directions are:

1. **Suppress the wrapper's implicit exports**, using explicit empty function
   and alias exports:

   ```powershell
   Export-ModuleMember -Function @() -Alias @()
   ```

2. **Perform test-package removal outside `InModuleScope Nitpick`**, leaving
   only registry cleanup inside it.

These are findings and corrective directions, not implemented fixes. The
investigation did not change repository files, existing edits were preserved,
and temporary diagnostic fixtures were removed.
