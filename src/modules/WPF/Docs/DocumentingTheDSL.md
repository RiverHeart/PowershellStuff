# Documenting This WPF DSL

This project already has the hardest part done: a clear mental model and lots of examples.
The goal of documentation is to make that model easy to discover.

## Start Here

If you are documenting a DSL for the first time, document in this order:

1. The core model
2. A tiny example
3. Keyword reference
4. Common patterns
5. Gotchas and limits

This order keeps docs useful even before they are complete.

## Core Model (Keep This Short)

Use these bullets almost verbatim:

- Keywords are PowerShell functions.
- Controls are declared using initializer args plus a trailing scriptblock.
- Inside each scriptblock, `$this` is the current object being configured.
- Returned child objects are attached by the parent during processing.
- `When` binds events within the current control scope.
- `Reference` looks up registered controls by name.

## Minimal Example

Use one compact example that demonstrates nesting and event binding:

```powershell
Import-Module ./WPF -Force

Window 'Main' {
    $this.Title = 'Hello DSL'

    StackPanel 'Layout' {
        Button 'Ping' {
            $this.Content = 'Click me'

            When Click {
                Write-Host 'Pong'
            }
        }
    }
} | Show-WPFWindow
```

## Keyword Reference Template

Use this template for each keyword page or section:

```markdown
### <Keyword>

Purpose: One sentence.

Syntax:
- <Keyword> 'Name' { ... }
- <Keyword> { ... }      # if nameless form is supported

Parameters:
- Name: <rules>
- ScriptBlock: required

Returns:
- <Type>

Notes:
- Auto-attach behavior
- Any special parent/child behavior

Example:
```powershell
<Keyword> ...
```
```

## Suggested First Keywords To Document

Document these first because they explain most of the DSL:

- `Window`
- `Grid`, `Row`, `Column`
- `StackPanel`
- `Button`
- `Border`
- `Path`
- `When`
- `Reference`
- `Style`, `Setter`, `Theme`, `Brush`, `Resource`

## Example Keyword Entries

### Border

Purpose: Creates a WPF `Border` control for visual grouping and decoration.

Syntax:

- `Border 'MyBorder' { ... }`
- `Border { ... }`

Notes:

- Supports named and nameless forms.
- Auto-attaches when created inside another control's scriptblock.

### Find-WPFChildPath

Purpose: Finds the first `System.Windows.Shapes.Path` under a dependency object.

Syntax:

- `Find-WPFChildPath -Node <DependencyObject>`

Notes:

- Checks logical children first (`Child`, `Content`, `Children`).
- Falls back to visual tree traversal.
- Returns `$null` if no path is found.

## Writing Style Guidelines

- Prefer short sections over long prose.
- Include one example per keyword.
- Keep terminology consistent: keyword, scriptblock, auto-attach, child object.
- Document behavior, not implementation details, unless behavior depends on it.

## Done Definition For DSL Docs

Treat docs as "good enough" when:

- A new reader can build a simple window without opening source code.
- A contributor can add one new keyword by following your pattern.
- Common errors are explained with at least one fix per error.

## Next Increment

Continue expanding [KeywordReference.md](./KeywordReference.md) with deeper examples and edge cases as keywords are touched.
Do not try to perfect it in one pass. Add sections incrementally as behavior changes.

## Agent Infrastructure Starter

This repository now has a minimal starter pack to speed up repetitive WPF DSL work:

- Skills:
    - [WPF DSL Keyword Change](../../../../.github/skills/WPF-DSL-Keyword-Change/SKILL.md)
    - [WPF DSL Documentation Update](../../../../.github/skills/WPF-DSL-Docs/SKILL.md)
- Agent profile:
    - [WPF DSL Maintainer](../../../../.github/agents/wpf-dsl-maintainer.agent.md)
- Process docs:
    - [Contribution Checklist](./ContributionChecklist.md)
    - [Keyword Entry Template](./Templates/KeywordEntryTemplate.md)

Use these as defaults for new DSL changes so code, tests, and docs stay synchronized.
