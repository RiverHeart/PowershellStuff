---
name: test-runner
description: Use when you need to discover, list, or run tests anywhere in this repository, including Pester suite discovery, tag discovery, and execution.
---

# Repository Test Runner

Use this skill when the task is about test discovery or execution for the repository as a whole.

This is the preferred path for any project in the workspace unless the user explicitly asks for a module-specific runner.

## What to use it for

- Listing configured suites.
- Listing tags for a suite.
- Running a configured suite with optional include or exclude tags.
- Summarizing results with compact output that is easy for agents to consume.

## Bundled asset

Use the bundled script asset at:

```powershell
"$(git rev-parse --show-toplevel)/.github/skills/test-runner/scripts/Invoke-Test.ps1"
```

Instead of reading the entire script, discover capabilities and usage with:

```powershell
Get-Help "$(git rev-parse --show-toplevel)/.github/skills/test-runner/scripts/Invoke-Test.ps1" -Detailed
```

## Workflow

1. Resolve the repository root from the current location or the script location.
2. Read the root pester.json manifest and validate the configured suite entry.
3. Resolve the suite config and test paths relative to the suite manifest.
4. Run targeted tests for changed code first (for example by IncludeTag, specific path, or focused filter).
5. If there are known failures from a prior run, re-run those failing tests before broad runs.
6. Keep the default edit/test loop fast by running tests without coverage.
7. Only run coverage when explicitly requested with `-IncludeCoverage` (for example, feature-complete validation or CI).
8. Keep tests and coverage as separate commands: finish the green test loop first, confirm feature completion with the user, then run a dedicated `-IncludeCoverage` execution.
9. Run full suite validation only after focused and known-failing tests pass.
10. Run Pester with PassThru and print a compact summary for each run.
11. Use ListSuites and ListTags when the user needs discovery rather than execution.
