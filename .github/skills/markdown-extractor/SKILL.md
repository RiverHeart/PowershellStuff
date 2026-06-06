---
name: markdown-extractor
description: Use when you need to discover markdown sections by slug and extract section content from markdown files in this repository.
---

# Markdown Section Extractor

Use this skill when the task is about discovering markdown section slugs or extracting content from specific sections.

This is the preferred path when an agent needs targeted markdown context without manually parsing full files.

## What to use it for

- Listing section slugs from a markdown file.
- Returning section metadata objects for navigation and diagnostics.
- Returning lightweight section size metadata via `ContentLineCount`.
- Extracting content lines for a known section slug.
- Extracting content as a single text payload for prompt injection workflows.
- Performing lightweight markdown discovery before targeted extraction.

## Bundled assets

Use the bundled markdown extractor script asset at:

```powershell
"$(git rev-parse --show-toplevel)/.github/skills/markdown-extractor/scripts/Get-MarkdownSection.ps1"
```

Instead of reading the entire script, discover capabilities and usage with:

```powershell
Get-Help "$(git rev-parse --show-toplevel)/.github/skills/markdown-extractor/scripts/Get-MarkdownSection.ps1" -Detailed
```

Use `Get-Help ... -Examples` when you only need invocation patterns.

## Recommended usage pattern

- For unknown markdown files, run a first pass with `-Name` to discover valid slugs.
- Then run targeted extraction with `-Section <slug> -Content`.
- Use `-Section <slug> -RawContent` when a single string payload is preferred.
- If you need richer context, use `-Section <slug>` to return the section object instead of content-only lines.

This two-step flow avoids manual reparsing logic in agent prompts and keeps calls deterministic.

## Workflow

1. Resolve the repository root from the current location or script location.
2. Dot-source the extractor script for the current shell session.
3. For unknown files, run slug discovery with `Get-MarkdownSection -Path <file> -Name`.
4. Validate the slug to avoid extraction errors.
5. Extract content with `Get-MarkdownSection -Path <file> -Section <slug> -Content`.
6. Use `-RawContent` when downstream tools expect one combined string.
7. If object metadata is required, use `Get-MarkdownSection -Path <file> -Section <slug>`.
8. Handle duplicate slugs as non-fatal: the command warns and returns the first match.

## Notes for agents

- Slug matching is case-insensitive in normal PowerShell equality behavior.
- Section detection ignores markdown headers inside triple-backtick code fences.
- Default object display excludes `Content`, but `Content` is present on returned objects for programmatic use.
- `Path` supports `ValueFromPipelineByPropertyName`, allowing object pipeline patterns.
