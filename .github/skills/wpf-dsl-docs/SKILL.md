---
name: wpf-dsl-docs
description: Use for creating and updating documentation for WPF DSL keywords, patterns, and behavior.
---

# Skill: WPF DSL Documentation Update

## Purpose

Use this skill when creating or updating DSL documentation for WPF keywords, patterns, and behavior.

## Inputs

- Target doc page(s)
- Keyword(s) affected
- Behavior changes or new examples

## Workflow

1. Start with src/modules/WPF/Docs/KeywordReference.md.
2. Add or update sections using concise syntax-first examples.
3. Keep docs aligned with real exported commands.
4. Link to deeper pages where needed (theme/style, examples, checklists).
5. Update src/modules/WPF/README.md documentation links when adding new pages.

## Style Rules

- Prefer short sections and practical examples.
- Use one clear example per keyword at minimum.
- Document behavior and constraints, not implementation trivia.

## Validation

- Confirm file links are valid.
- Ensure no stale syntax that disagrees with current function signatures.

## Completion Criteria

- New content is discoverable from README or existing docs hub.
- KeywordReference remains the canonical quick-start reference.
