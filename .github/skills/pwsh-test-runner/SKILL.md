---
name: pwsh-test-runner
description: Use when you need to discover, list, or run PowerShell tests across repository projects and suites, including Pester tag discovery and execution.
---

# Repository Test Runner

Use this skill when the task is about test discovery or execution for the repository as a whole.

This is the preferred path for any project in the workspace unless the user explicitly asks for a module-specific runner.

## Configuration model

A root `pester.json` marked with `"isRoot": true` uses exactly one layout:

- `Projects` maps project names to project config files.
- `TestSuites` defines named suites for one project; each entry has an inline
  `Run` configuration or a `ConfigPath`.
- `Run` defines all tests for one project without requiring a suite name.

A project config referenced by `Projects` may itself use `Run` or `TestSuites`.
With no selectors, `Invoke-MDKTest` runs every configured project and suite.
Use `-Project` and optionally `-TestSuite` to narrow execution. A suite name
shared by multiple projects selects that suite in each matching project, so use
`-Project` to restrict it to one.

## What to use it for

- Listing configured projects and test targets.
- Listing tags for one or more selected targets.
- Running all configured tests, a project, or a project's named suite.
- Running specific files or directories within selected targets.
- Summarizing results with compact output that is easy for agents to consume.

## Repository tools

Import the repository's ModuleDevKit module from the repository root:

```powershell
Import-Module ./src/modules/ModuleDevKit/ModuleDevKit.psd1 -Force
```

Use `-ListSuites` to inspect the configured targets:

```powershell
Invoke-MDKTest -ListSuites
```

With no selectors, `Invoke-MDKTest` runs every configured target. Prefer
`-Project` (and `-TestSuite` where needed) for the normal focused test loop.

Use the dedicated module command for coverage and optional new-code gating:

```powershell
Invoke-MDKTestCoverage -Project ModuleDevKit -TestSuite ModuleDevKit
```

Coverage must resolve to exactly one target. Supply `-Project`, `-TestSuite`,
or both when the configuration contains multiple targets.

Instead of reading the entire script, discover capabilities and usage with:

```powershell
Get-Help Invoke-MDKTest -Detailed
```

Use compact output by default. Only enable detailed Pester console output when needed with `-DetailedOutput`.
Use `Invoke-MDKTestCoverage` when you need a dedicated coverage command and optional new-code gate integration.

## Common invocations

Run all suites in one project:

```powershell
Import-Module ./src/modules/ModuleDevKit/ModuleDevKit.psd1 -Force
Invoke-MDKTest -Project ModuleDevKit
```

Run one configured suite (`-Suite` is an alias for `-TestSuite`):

```powershell
Import-Module ./src/modules/ModuleDevKit/ModuleDevKit.psd1 -Force
Invoke-MDKTest -Project TabCentral -TestSuite TabCentral
```

The host used to launch `Invoke-MDKTest` selects the PowerShell runtime. Always
run tests through the repository runner so it can restore the edition-specific
CurrentUser module path before discovering Pester. For a PowerShell 5.1 run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `
    'Import-Module ./src/modules/ModuleDevKit/ModuleDevKit.psd1 -Force; Invoke-MDKTest -Project AstEditor -TestSuite AstEditor'
```

Do not probe Pester availability by launching `powershell.exe` directly from
`pwsh`; the inherited `PSModulePath` can hide Windows PowerShell user modules.

```powershell
powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -Command 'Import-Module ./src/modules/ModuleDevKit/ModuleDevKit.psd1 -Force; Invoke-MDKTest -Project AstEditor -TestSuite AstEditor -Path Tests/A.Tests.ps1,Tests/B.Tests.ps1'
```

Use `-ExitOnError` for external automation that needs a failed run to terminate
the host with exit code 2. A run is failed when any test fails, or when a test
file fails discovery (for example a parse error) or a block fails setup; those
are printed as `[-] Container failed:` / `[-] Block failed:` lines and a
`Failed Containers: N, Failed Blocks: M` summary line, since they do not count
toward `Tests Passed`/`Failed`:

```powershell
Invoke-MDKTest -Project TabCentral -ExitOnError
```

Run one or more focused paths instead of all paths configured by the suite:

```powershell
Invoke-MDKTest `
    -Project TabCentral `
    -TestSuite TabCentral `
    -Path Tests/TabCentralState.tests.ps1
```

Relative `-Path` values are resolved from the directory containing each selected
target's configuration file. Absolute paths are also accepted. Use
`-DetailedOutput` when full Pester discovery and test output is needed:

```powershell
Invoke-MDKTest `
    -Project TabCentral `
    -TestSuite TabCentral `
    -Path Tests/TabCentralState.tests.ps1 `
    -DetailedOutput
```

## Coverage note

- The runner defaults coverage to `UseBreakpoints = false` unless the selected config explicitly sets `Coverage.UseBreakpoints`.
- Some suites may show intermittent failures in one coverage mode but not the other.
- Treat this as an execution-mode edge case and record observed behavior without assuming a confirmed root cause.
- If a suite is unstable in non-breakpoint coverage mode, set `Coverage.UseBreakpoints` in that suite's `pester.json`.

## Workflow

1. Resolve the repository root from the current location or the script location.
2. Read the root pester.json layout (`Projects`, `TestSuites`, or `Run`) and validate the selected project and suite configs.
3. Resolve each selected target's config and test paths relative to that config file.
4. Run targeted tests for changed code first (for example with `-Tag` or `-Path`).
5. If there are known failures from a prior run, re-run those failing tests before broad runs.
6. Keep the default edit/test loop fast by running tests without coverage.
7. Only run coverage when explicitly requested (for example, feature-complete validation or CI) using `Invoke-MDKTestCoverage -Project <Project> [-TestSuite <Suite>]` or `Invoke-MDKTest -CoverageMode Full`.
8. Keep tests and coverage as separate commands: finish the green test loop first, confirm feature completion with the user, then run a dedicated coverage command.
9. Run full suite validation only after focused and known-failing tests pass.
10. Run Pester with PassThru and print a compact summary for each run.
11. Use `Invoke-MDKTest -ListSuites` and `Invoke-MDKTest -ListTags` when the user needs discovery rather than execution.
