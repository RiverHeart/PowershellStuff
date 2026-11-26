---
name: pwsh-test-runner
description: Use when you need to discover, list, or run PowerShell tests anywhere in this repository, including Pester suite discovery, tag discovery, and execution.
---

# Repository Test Runner

Use this skill when the task is about test discovery or execution for the repository as a whole.

This is the preferred path for any project in the workspace unless the user explicitly asks for a module-specific runner.

## What to use it for

- Listing configured suites.
- Listing tags for a suite.
- Running a configured suite with optional include or exclude tags.
- Running specific files or directories within a configured suite.
- Summarizing results with compact output that is easy for agents to consume.

## Repository tools

Import the repository's ModuleDevKit module from the repository root:

```powershell
Import-Module ./src/modules/ModuleDevKit/ModuleDevKit.psd1 -Force
```

Then use the module's test runner:

```powershell
Invoke-MDKTest
```

Use the dedicated module command for coverage and optional new-code gating:

```powershell
Invoke-MDKTestCoverage
```

Instead of reading the entire script, discover capabilities and usage with:

```powershell
Get-Help Invoke-MDKTest -Detailed
```

Use compact output by default. Only enable detailed Pester console output when needed with `-DetailedOutput`.
Use `Invoke-MDKTestCoverage` when you need a dedicated coverage command and optional new-code gate integration.

## Common invocations

Run a configured suite (`-Suite` is an alias for `-TestSuite`):

```powershell
Import-Module ./src/modules/ModuleDevKit/ModuleDevKit.psd1 -Force
Invoke-MDKTest -Suite TabCentral
```

The host used to launch `Invoke-MDKTest` selects the PowerShell runtime. Always
run tests through the repository runner so it can restore the edition-specific
CurrentUser module path before discovering Pester. For a PowerShell 5.1 run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `
    'Import-Module ./src/modules/ModuleDevKit/ModuleDevKit.psd1 -Force; Invoke-MDKTest -Suite AstEditor'
```

Do not probe Pester availability by launching `powershell.exe` directly from
`pwsh`; the inherited `PSModulePath` can hide Windows PowerShell user modules.

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -Command 'Import-Module ./src/modules/ModuleDevKit/ModuleDevKit.psd1 -Force; Invoke-MDKTest -Suite AstEditor -Path Tests/A.Tests.ps1,Tests/B.Tests.ps1'
```

Use `-ExitOnError` for external automation that needs a failed run to terminate
the host with exit code 2. A run is failed when any test fails, or when a test
file fails discovery (for example a parse error) or a block fails setup; those
are printed as `[-] Container failed:` / `[-] Block failed:` lines and a
`Failed Containers: N, Failed Blocks: M` summary line, since they do not count
toward `Tests Passed`/`Failed`:

```powershell
Invoke-MDKTest -Suite TabCentral -ExitOnError
```

Run one or more focused paths instead of all paths configured by the suite:

```powershell
Invoke-MDKTest `
    -Suite TabCentral `
    -Path Tests/TabCentralState.tests.ps1
```

Relative `-Path` values are resolved from the directory containing the selected suite's configuration file. Absolute paths are also accepted. Use `-DetailedOutput` when full Pester discovery and test output is needed:

```powershell
Invoke-MDKTest `
    -Suite TabCentral `
    -Path Tests/TabCentralState.tests.ps1 `
    -DetailedOutput
```

## Coverage note

- The runner defaults coverage to `UseBreakpoints = false` unless the suite config explicitly sets `Coverage.UseBreakpoints`.
- Some suites may show intermittent failures in one coverage mode but not the other.
- Treat this as an execution-mode edge case and record observed behavior without assuming a confirmed root cause.
- If a suite is unstable in non-breakpoint coverage mode, set `Coverage.UseBreakpoints` in that suite's `pester.json`.

## Workflow

1. Resolve the repository root from the current location or the script location.
2. Read the root pester.json manifest and validate the configured suite entry.
3. Resolve the suite config and test paths relative to the suite manifest.
4. Run targeted tests for changed code first (for example with `-Tag` or `-Path`).
5. If there are known failures from a prior run, re-run those failing tests before broad runs.
6. Keep the default edit/test loop fast by running tests without coverage.
7. Only run coverage when explicitly requested (for example, feature-complete validation or CI) using `Invoke-MDKTestCoverage -TestSuite <Suite>` or `Invoke-MDKTest -CoverageMode Full`.
8. Keep tests and coverage as separate commands: finish the green test loop first, confirm feature completion with the user, then run a dedicated coverage command.
9. Run full suite validation only after focused and known-failing tests pass.
10. Run Pester with PassThru and print a compact summary for each run.
11. Use ListSuites and ListTags when the user needs discovery rather than execution.
