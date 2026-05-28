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
- `Run-ImageViewerMutation.ps1`: end-to-end demo against the WPF ImageViewer DSL script

## Core Model

- `AstTextEdit`: single replacement/insertion operation
- `AstMutationPlan`: ordered collection of edits with overlap conflict detection
- `AstOverlayDocument`: immutable parse data plus mutable edit plan

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
