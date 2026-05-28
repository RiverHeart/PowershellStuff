---
name: bulk-replace
description: Use this skill when you need to perform a bulk find-and-replace across multiple files with support for literal and regex patterns, file filtering, and dry-run previews.
---

# Skill: Bulk Replace

## Purpose

This skill aims to give agents the ability to make large-scale text changes across the codebase in a controlled and previewable way, reducing manual effort and the risk of missing occurrences.

## Workflow

1. Run search-first using `-SearchOnly`.
2. Validate matches with summary output first.
3. Apply with `-WhatIf` for preview.
4. Apply for real only after preview looks correct.
5. Use Detailed pass-through only when line-level review is needed.

## Bundled asset

Use the bundled script asset at:

```powershell
"$(git rev-parse --show-toplevel)/.github/skills/bulk-replace/scripts/Invoke-BulkReplace.ps1"
```

Instead of reading the entire script, discover capabilities and usage with:

```powershell
Get-Help "$(git rev-parse --show-toplevel)/.github/skills/bulk-replace/scripts/Invoke-BulkReplace.ps1" -Detailed
```
