# AstEditor

PowerShell module for editing source through immutable ASTs and validated text overlays.

This project demonstrates a practical approach to AST manipulation in PowerShell:

- Keep native AST immutable
- Track mutations as text edits keyed by AST extents
- Detect and reject conflicting edits
- Render to new text
- Re-parse for validation before writing output

## Files

- `AstEditor.psd1`: module manifest and public export list
- `AstEditor.psm1`: module loader
- `Classes/`: internal document and text-edit classes
- `Private/`: internal rewrite planning and emission helpers
- `Public/`: exported editing commands
- `Run-SimpleExample.ps1`: minimal demo showing prepend/replace/append line edits
- `Run-ImageViewerMutation.ps1`: end-to-end demo against the WPF ImageViewer DSL script
- `Tests/AstEditor.tests.ps1`: Pester coverage for document parsing, line helpers, diff output, and WPF transform behavior

## Import

Import the module and create documents through its public commands:

```powershell
Import-Module ./AstEditor.psd1

$document = New-AstDocument -InputObject 'function Get-Greeting {}'
Resolve-AstDocument -Document $document
```

`AstDocument` and `AstTextEdit` are internal implementation types. Consumers should instantiate
documents through `New-AstDocument` and pass the returned objects to the other exported commands.

## Core Model

- `AstTextEdit`: internal representation of a single replacement/insertion operation
- `AstDocument`: internal immutable parse data plus a queued list of `AstTextEdit` edits
- `New-AstDocument`: factory for parsing input and creating an `AstDocument`
- `Resolve-AstDocument`: renders queued edits and validates parse correctness
- `Show-AstDiff`: displays all or selected queued edits by index
- `Save-AstDocument`: writes rendered output after parse validation
- `Set-AstFunction`: queues replacement of one structurally selected function
- `Edit-PSFunction`: previews or explicitly applies a function replacement to a file
- `Extract-AstFunction`: queues removal of one function and returns its source text
- `Split-PSFunction`: previews or applies extraction of top-level functions into individual files

## Function Editing

`Set-AstFunction` is the composable transform. Replacement text must contain exactly one complete
function definition:

```powershell
$document = New-AstDocument -Path ./Module.psm1
$plan = Set-AstFunction `
	-Document $document `
	-Name Get-Greeting `
	-Replacement @'
function Get-Greeting {
	'Hello'
}
'@

Show-AstDiff -Document $document
Save-AstDocument -Document $document
```

`Edit-PSFunction` provides a preview-first workflow for agents and command-line use. It returns a
structured result containing the diff, parse diagnostics, rewrite metadata, and document. It does
not change the file unless `-Apply` is specified:

```powershell
$preview = Edit-PSFunction `
	-Path ./Module.psm1 `
	-Name Get-Greeting `
	-Replacement $replacement

$preview.Diff

Edit-PSFunction `
	-Path ./Module.psm1 `
	-Name Get-Greeting `
	-Replacement $replacement `
	-Apply
```

Selection is case-insensitive and restricted to top-level functions by default. Use `-Recurse` to
include nested definitions; ambiguous matches are rejected with source locations. Contiguous
comment-based help immediately above the target is replaced with the function by default. Use
`-ExcludeHelp` to preserve it.

The current MVP replaces complete function definitions. It does not yet perform semantic renames,
body-only edits, concurrent file-change detection, atomic writes, or encoding preservation.

## Function Extraction

`Extract-AstFunction` is the composable transform. It queues removal of one top-level function
from an `AstDocument` and returns a plan whose `Text` property contains the extracted definition.
Adjacent comment-based help is included by default.

`Split-PSFunction` provides the file-oriented workflow. It extracts every top-level function when
`Name` is omitted, writes each function to `<FunctionName>.ps1`, and leaves other source content in
place. The default mode is a preview; use `-Apply` to write the source and extracted files:

```powershell
$preview = Split-PSFunction `
	-Path ./Module.psm1 `
	-OutputDirectory ./Private

$preview.Files
$preview.Diff

Split-PSFunction `
	-Path ./Module.psm1 `
	-OutputDirectory ./Private `
	-Apply
```

Pass `-Name Get-One, Get-Two` to select functions. Existing destination files are rejected unless
`-Force` is specified. `-WhatIf` and `-Confirm` are supported when applying the split.

### Extraction TODOs

- Add newline when saving extracted function.
- Find all type declarations and attempt to determine any `using` statements that need included with the extraction.
- Continue excluding constructors and methods beneath type definitions from top-level discovery.
- Report class and other lexical type dependencies that may not resolve after extraction.
- Support caller-provided destination classification, such as mapping functions to `Public` or `Private`.

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

AstEditor intentionally avoids mutating PowerShell AST objects in-place.
It treats AST as a query surface and source of stable spans, while all changes are represented in an overlay plan.
