---
name: pwsh-test-runner
description: Use when you need to discover, list, or run Powershell tests anywhere in this repository, including Pester suite discovery, tag discovery, and execution.
---

# Repository Test Runner

Use this skill when the task is about test discovery or execution for the repository as a whole.

This is the preferred path for any project in the workspace unless the user explicitly asks for a module-specific runner.

## What to use it for

- Listing configured suites.
- Listing tags for a suite.
- Running a configured suite with optional include or exclude tags.
- Summarizing results with compact output that is easy for agents to consume.

## Bundled assets

Use the bundled test runner script asset at:

```powershell
"$(git rev-parse --show-toplevel)/.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1"
```

Use the bundled coverage runner script asset at:

```powershell
"$(git rev-parse --show-toplevel)/.github/skills/pwsh-test-runner/scripts/Invoke-TestCoverage.ps1"
```

Instead of reading the entire script, discover capabilities and usage with:

```powershell
Get-Help "$(git rev-parse --show-toplevel)/.github/skills/pwsh-test-runner/scripts/Invoke-Test.ps1" -Detailed
```

Use compact output by default. Only enable detailed Pester console output when needed with `-DetailedOutput`.
Use `Invoke-TestCoverage.ps1` when you need a dedicated coverage command and optional new-code gate integration.

## Coverage note

- The runner defaults coverage to `UseBreakpoints = false` unless the suite config explicitly sets `Coverage.UseBreakpoints`.
- Some suites may show intermittent failures in one coverage mode but not the other.
- Treat this as an execution-mode edge case and record observed behavior without assuming a confirmed root cause.
- If a suite is unstable in non-breakpoint coverage mode, set `Coverage.UseBreakpoints` in that suite's `pester.json`.

## Workflow

1. Resolve the repository root from the current location or the script location.
2. Read the root pester.json manifest and validate the configured suite entry.
3. Resolve the suite config and test paths relative to the suite manifest.
4. Run targeted tests for changed code first (for example by IncludeTag, specific path, or focused filter).
5. If there are known failures from a prior run, re-run those failing tests before broad runs.
6. Keep the default edit/test loop fast by running tests without coverage.
7. Only run coverage when explicitly requested (for example, feature-complete validation or CI) using `Invoke-Test.ps1 -CoverageMode Full` or `Invoke-TestCoverage.ps1`.
8. Keep tests and coverage as separate commands: finish the green test loop first, confirm feature completion with the user, then run a dedicated coverage command.
9. Run full suite validation only after focused and known-failing tests pass.
10. Run Pester with PassThru and print a compact summary for each run.
11. Use ListSuites and ListTags when the user needs discovery rather than execution.
