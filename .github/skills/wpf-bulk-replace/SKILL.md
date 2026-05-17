---
name: wpf-bulk-replace
description: Use for safe, reusable bulk text replacement in WPF module files with preview/search-first workflows.
---

# Skill: WPF Bulk Replace

## Purpose

Use this skill when applying repeated text edits across many files in the WPF module while minimizing risk and chat verbosity.

## Inputs

- Target path(s)
- Scope filters (Include/Exclude/Recurse)
- Rule source:
  - Rule object array, or
  - Rule file via RulePath (.json/.psd1), or
  - Find/Replace convenience parameters
- Optional mode flags:
  - SearchOnly
  - WhatIf
  - PassThru
  - PassThruFormat (Summary or Detailed)

## Workflow

1. Run search-first using SearchOnly.
2. Validate matches with summary output first.
3. Apply with WhatIf for preview.
4. Apply for real only after preview looks correct.
5. Use Detailed pass-through only when line-level review is needed.

## Tool

Use:

`src/modules/WPF/Scripts/Invoke-WPFBulkReplace.ps1`

## Guardrails

- Prefer PassThruFormat Summary by default to reduce output volume.
- Keep rule scope narrow with Path/Include/Exclude/FilePattern.
- Use explicit exceptions in rule files rather than broad ad hoc regex.
- If replacements touch tests, run focused Pester tests for changed areas.

## Completion Criteria

- Search shows only intended targets.
- Replace run updates expected files and no unexpected files.
- Focused tests pass for touched functionality.

## Examples

### 1) Search Only (compact output)

```powershell
./src/modules/WPF/Scripts/Invoke-WPFBulkReplace.ps1 `
  -Path 'src/modules/WPF/Tests' `
  -Recurse `
  -Include '*.Tests.ps1' `
  -SearchOnly `
  -Find "Describe '([^']+)' \{" `
  -UseRegex `
  -PassThru
```

### 2) Search Only (line-level details)

```powershell
./src/modules/WPF/Scripts/Invoke-WPFBulkReplace.ps1 `
  -Path 'src/modules/WPF/Tests/BindProperty.Tests.ps1' `
  -SearchOnly `
  -Find "Describe 'BindProperty'" `
  -PassThru `
  -PassThruFormat Detailed
```

### 3) Preview replacement with WhatIf

```powershell
./src/modules/WPF/Scripts/Invoke-WPFBulkReplace.ps1 `
  -Path 'src/modules/WPF/Tests/BindProperty.Tests.ps1' `
  -Find "Describe 'BindProperty' {" `
  -Replace "Describe 'BindProperty' -Tag 'BindProperty' {" `
  -WhatIf `
  -PassThru
```

### 4) Apply replacement

```powershell
./src/modules/WPF/Scripts/Invoke-WPFBulkReplace.ps1 `
  -Path 'src/modules/WPF/Tests/BindProperty.Tests.ps1' `
  -Find "Describe 'BindProperty' {" `
  -Replace "Describe 'BindProperty' -Tag 'BindProperty' {" `
  -PassThru
```

### 5) Load rules from a file

```powershell
./src/modules/WPF/Scripts/Invoke-WPFBulkReplace.ps1 `
  -Path 'src/modules/WPF/Tests' `
  -Recurse `
  -Include '*.Tests.ps1' `
  -RulePath './src/modules/WPF/Scripts/rules/tagging.json' `
  -WhatIf `
  -PassThru
```

### 6) Regex capture replacement (generic pattern rewrite)

```powershell
./src/modules/WPF/Scripts/Invoke-WPFBulkReplace.ps1 `
  -Path 'src/modules/WPF/Tests' `
  -Recurse `
  -Include '*.Tests.ps1' `
  -Find "^Describe '([^']+)' \{$" `
  -Replace "Describe '$1' -Tag '$1' {" `
  -UseRegex `
  -WhatIf `
  -PassThru `
  -PassThruFormat Detailed
```
