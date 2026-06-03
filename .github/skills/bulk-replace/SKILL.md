---
name: bulk-replace
description: Use this skill when you need to perform a bulk find-and-replace across multiple files with support for literal and regex patterns, file filtering, and dry-run previews.
---

# Skill: Bulk Replace

## Purpose

This skill aims to give agents the ability to make large-scale text changes across the codebase in a controlled and previewable way, reducing manual effort and the risk of missing occurrences.

Best fit: broad, repeatable transformations with clear textual patterns.

Lower fit: high-precision edge migrations where a small regex mistake can change semantics; prefer focused/manual PowerShell in those cases.

## Workflow

1. Run search-first using `-SearchOnly`.
2. For multiline regex patterns, use `-SearchOnly -SearchMultiline`.
3. Validate matches with summary output first.
4. Apply with `-WhatIf` for preview.
5. Apply for real only after preview looks correct.
6. Use Detailed pass-through only when line-level review is needed.

When using regex replacement with literal text that contains `$` or backreference-like content, add `-LiteralReplacement` to avoid replacement-token expansion.

## Bundled asset

Use the bundled script asset at:

```powershell
"$(git rev-parse --show-toplevel)/.github/skills/bulk-replace/scripts/Invoke-BulkReplace.ps1"
```

Instead of reading the entire script, discover capabilities and usage with:

```powershell
Get-Help "$(git rev-parse --show-toplevel)/.github/skills/bulk-replace/scripts/Invoke-BulkReplace.ps1" -Detailed
```

## Verification

When this skill or its script is modified, validate with:

```powershell
Invoke-Pester -Path "$(git rev-parse --show-toplevel)/.github/skills/bulk-replace/tests/Invoke-BulkReplace.Tests.ps1"
```
