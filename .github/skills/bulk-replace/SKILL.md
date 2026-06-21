---
name: bulk-replace
description: Use this skill when you need to perform a bulk find-and-replace across multiple files with support for literal and regex patterns, file filtering, and dry-run previews.
---

# Skill: Bulk Replace

## Purpose

This skill aims to give agents the ability to make large-scale text changes across the codebase in a controlled and previewable way, reducing manual effort and the risk of missing occurrences.

Best fit: broad, repeatable transformations with clear textual patterns.

Lower fit: high-precision edge migrations where a small regex mistake can change semantics; prefer focused/manual PowerShell in those cases.

### Use this skill when

- You need the same text transformation across many files.
- A clear literal or regex pattern can identify the target edits.
- You want a preview-first workflow before writing changes.

### Prefer direct edits/patches when

- Only 1-3 files need changes.
- Replacements depend on local semantics or AST structure.
- The pattern would be too broad and hard to constrain safely.

## Workflow

1. Run search-first using `-SearchOnly`.
2. For multiline regex patterns, use `-SearchOnly -SearchMultiline`.
3. Validate matches with summary output first.
4. Spot-check at least 2-3 representative files from different folders.
5. For semantic renames, verify matches are code references (not only prose/comments).
6. Apply with `-WhatIf` for preview.
7. Apply for real only after preview looks correct.
8. Use Detailed pass-through only when line-level review is needed.

### Recommended safe preset (code migration)

Use this sequence for large renames/refactors:

1. `-SearchOnly -PassThru` to inspect initial matches.
2. Narrow pattern/scope (`-Path`, `-FilePattern`, `-Include`, `-Exclude`) until matches are clean.
3. `-WhatIf` to preview changed files/counts.
4. Apply for real.

Example:

```powershell
$tool = "$(git rev-parse --show-toplevel)/.github/skills/bulk-replace/scripts/Invoke-BulkReplace.ps1"

# 1) Search and inspect
& $tool -Path src -Recurse -FilePattern *.ps1 -UseRegex -Find '\\bWhen (?=[''\"A-Z])' -Replace 'On ' -SearchOnly -PassThru

# 2) Preview write impact
& $tool -Path src -Recurse -FilePattern *.ps1 -UseRegex -Find '\\bWhen (?=[''\"A-Z])' -Replace 'On ' -WhatIf

# 3) Apply
& $tool -Path src -Recurse -FilePattern *.ps1 -UseRegex -Find '\\bWhen (?=[''\"A-Z])' -Replace 'On '
```

### Regex narrowing tips

- Prefer word boundaries (`\\b`) to avoid partial-token matches.
- Add contextual guards (for example uppercase/PascalCase lookaheads) to reduce prose hits.
- Start broad in search-only mode, then tighten incrementally.

### Comments/strings and false positives

- This tool is text-based, not AST-aware.
- During semantic renames, run a code-only pass first (for example `*.ps1`, `*.psm1`, `*.psd1`) and review docs/comments separately.
- If comments/docs need updates too, run a second explicit pass after code validation.

### Multiline replacement caution

- Multiline literal replacements are more brittle than token-level regex replacements.
- Prefer small, composable replacements over one large multiline replacement when possible.

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
