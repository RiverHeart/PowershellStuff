---
name: bulk-replace
description: Use this skill when you need to perform a bulk find-and-replace across multiple files in the repository, with support for literal and regex patterns, file filtering, and dry-run previews.
---

# Skill: Bulk Replace

This skill provides a way to perform bulk find-and-replace operations across multiple files in the repository, with support for both literal and regex patterns, file filtering, and dry-run previews.

## Purpose

This skill aims to give agents the ability to make large-scale text changes across the codebase in a controlled and previewable way, reducing manual effort and the risk of missing occurrences.

## Bundled asset

Use the bundled script asset at:

```powershell
./.github/skills/bulk-replace/scripts/Invoke-BulkReplace.ps1
```
