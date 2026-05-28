# AstOverlayLab

Experimental PowerShell AST overlay framework.

This project demonstrates a practical approach to AST manipulation in PowerShell:

- Keep native AST immutable
- Track mutations as text edits keyed by AST extents
- Detect and reject conflicting edits
- Render to new text
- Re-parse for validation before writing output

## Files

- `AstOverlay.ps1`: core classes and helper functions
- `Run-SimpleExample.ps1`: minimal demo showing prepend/replace/append line edits
- `Run-ImageViewerMutation.ps1`: end-to-end demo against the WPF ImageViewer DSL script
- `Tests/AstOverlay.tests.ps1`: Pester coverage for document parsing, line helpers, diff output, and WPF transform behavior

## Core Model

- `AstTextEdit`: single replacement/insertion operation
- `AstDocument`: immutable parse data plus a queued list of `AstTextEdit` edits
- `New-AstDocument`: factory for parsing input and creating an `AstDocument`
- `Resolve-AstDocument`: renders queued edits and validates parse correctness
- `Show-AstDiff`: displays all or selected queued edits by index
- `Save-AstDocument`: writes rendered output after parse validation

## WPF DSL Transform (first pass)

`Add-WpfDslLoadedHandler` is a targeted transform that:

1. Finds `Window <name> { ... }`
2. Checks for `When 'Loaded' { ... }`
3. Inserts a handler block if missing

## Run Demo

From this folder:

```powershell
pwsh ./Run-ImageViewerMutation.ps1
```

Output is written to:

- `ImageViewer.DSL.mutated.ps1`

## Notes

This prototype intentionally avoids mutating PowerShell AST objects in-place.
It treats AST as a query surface and source of stable spans, while all changes are represented in an overlay plan.
