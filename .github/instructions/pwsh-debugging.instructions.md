---
name: PowerShell Debugging Guide
description: Use when investigating PowerShell failures, order-dependent tests, state leaks, or module/session-state scope issues. Covers non-interactive breakpoint probes and controlled reproductions.
---

# Debugging State and Scope

- For order-dependent failures or state leaks, consider non-interactive `Set-PSBreakpoint -Action` probes before adding diagnostic statements to source files. Observe state before and after the suspected operation to find the first incorrect transition, not just the later failing assertion.
- Run probes in a fresh PowerShell process where practical. Keep actions observational first; label any action that changes state as a separate controlled experiment.
- Capture only relevant state, such as command identity, module path, and registry counts. `Get-Module -All` and `Get-Command` answer different questions: an empty module list does not prove that exported commands were removed.
- Do not assume a breakpoint action evaluates in the target module's session state. Inspect module-local state explicitly through its module object, for example `& (Get-Module Example) { Get-Command Test-Foo }`, or through Pester's `InModuleScope` when appropriate.
- Preserve existing breakpoints. Store the objects returned by `Set-PSBreakpoint` and remove only those objects in `finally`, even if execution fails.

Example template from the repository root; replace the suite name, test path, and command name with real targets, and choose executable lines around the suspected transition rather than copying fixed line numbers:

```powershell
$TestPath = Join-Path $PWD 'Example.ps1'
$SuiteName = 'YourConfiguredSuite'
$ProbeLines = 94, 101
$Breakpoints = Set-PSBreakpoint -Script $TestPath -Line $ProbeLines -Action {
    $Commands = @(Get-Command Test-Foo -All -ErrorAction SilentlyContinue)
    Write-Host "PROBE commands=$($Commands.Count) paths=$($Commands.Module.Path -join '|')"
}
try {
    & .\tools\Invoke-Test.ps1 -Suite $SuiteName -Path $TestPath
} finally {
    $Breakpoints | Remove-PSBreakpoint
}
```

Before test execution, load the `pwsh-test-runner` skill and use the repository runner. Breakpoint actions are probes, not replacement assertions; confirm the explanation with a focused test or minimal reproduction.

For module-scope leaks, remember that `New-Module -ReturnResult` does not suppress implicit function exports. A wrapper intended only to retain private module scope should explicitly use `Export-ModuleMember -Function @() -Alias @()`. Remove imported test modules from the importing session state, rather than assuming removal from another module's scope cleans up every exported command.
