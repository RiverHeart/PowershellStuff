---
name: wpf-ps5-test-compatibility
description: Use this skill when adding or updating WPF tests, test runners, or CI so PowerShell 5.1 compatibility remains the primary quality gate.
---

# Skill: WPF PS5 Test Compatibility

## Purpose

Use this skill when changing tests, test helpers, manifests, or CI behavior for the WPF module.

PowerShell 5.1 compatibility is a project goal. Treat Windows PowerShell 5.1 as the primary compatibility gate and PowerShell 7 as a secondary gate.

## Inputs

- Files changed in `src/modules/WPF/Tests` and related test helpers
- Any CI or local runner changes
- Any compatibility claims added to README/docs

## Workflow

1. Confirm the change runs under Windows PowerShell 5.1 first.
2. Run the same tests under PowerShell 7 after 5.1 validation.
3. Use `./.github/skills/test-runner/scripts/Invoke-Test.ps1 -TestSuite WPF` as the default test invocation path.
4. Keep test syntax and helpers compatible with 5.1 unless runtime-specific behavior is intentional.
5. If behavior differs by runtime, use narrowly scoped skips/branches and document why.
6. Ensure compatibility messaging in docs matches actual test coverage.
7. Verify `src/modules/WPF/WPF.psd1` declares a compatible `PowerShellVersion` floor.

## Pester Policy

- Do not rely on whatever Pester version happens to be preinstalled.
- Require `Pester` version `5.7.1` or newer in both Windows PowerShell 5.1 and PowerShell 7.
- Use a known Pester version in test automation so local and CI runs are consistent.
- In Windows PowerShell 5.1, explicitly import the required version to avoid accidentally running the inbox Pester.
- Use the repository test runner as the default entrypoint:

```powershell
./.github/skills/test-runner/scripts/Invoke-Test.ps1 -TestSuite WPF
```

- Use direct `Invoke-Pester` only when explicitly validating Pester version pinning behavior, for example:

```powershell
Remove-Module Pester -ErrorAction SilentlyContinue
Import-Module Pester -MinimumVersion 5.7.1 -Force
Invoke-Pester -Path "src/modules/WPF/Tests" -Output Detailed
```

If the required version is not installed, install it first (CurrentUser scope):

```powershell
Install-Module Pester -MinimumVersion 5.7.1 -Scope CurrentUser -Force
```

Before running `Install-Module`, ask the user for explicit permission.

## Recommended Execution Order

Run tests in this order when validating a change:

```powershell
# Primary gate
powershell.exe -NoProfile -File ".github/skills/test-runner/scripts/Invoke-Test.ps1" -TestSuite WPF

# Secondary gate
pwsh.exe -NoProfile -File ".github/skills/test-runner/scripts/Invoke-Test.ps1" -TestSuite WPF
```

If PowerShell 7 passes but PowerShell 5.1 fails, treat the change as incompatible.

## Guardrails

- Avoid introducing PS7-only test syntax by accident.
- Avoid broad runtime skips that hide regressions.
- Keep compatibility tradeoffs explicit in docs when they are intentional.
- Do not install modules automatically without user approval.

## Completion Criteria

- WPF tests pass in Windows PowerShell 5.1.
- WPF tests pass in PowerShell 7, or any runtime-specific differences are explicitly justified.
- Test runs in both runtimes use `Pester >= 5.7.1`.
- Manifest compatibility floor and docs are aligned with tested behavior.
