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

`AstDocument` remains an internal implementation type. Consumers create documents through
`New-AstDocument` and detached edits through `New-AstTextEdit` or structural edit commands.

## Core Model

- `AstTextEdit`: class-based detached edit contract with source coordinates, expected text, replacement text, and reason
- `AstDocument`: internal immutable parse data plus a queued edit list
- `New-AstDocument`: factory for parsing input and creating an `AstDocument`
- `New-AstTextEdit`: creates a detached edit from an extent or document-bound offset range
- `New-AstCollectionEdit`: creates the same detached edit contract for a structural collection removal
- `Add-AstTextEdit`: atomically validates and queues one or more detached edits
- `Resolve-AstDocument`: renders queued edits and validates parse correctness
- `Show-AstDiff`: displays all or selected queued edits by index
- `Save-AstDocument`: validates and transactionally saves output with a structured write result
- `Set-AstFunction`: queues replacement of one structurally selected function
- `Edit-PSFunction`: previews or explicitly applies a function replacement to a file
- `Extract-AstFunction`: queues removal of one function and returns its source text
- `Split-PSFunction`: previews or applies extraction of top-level functions into individual files

## Generic Text Edits

Offset ranges are zero-based and end-exclusive. Construct edits without side effects, then submit
the selected target batch to `Add-AstTextEdit`:

```powershell
$document = New-AstDocument -InputObject '$Value = 1'
$edit = New-AstTextEdit `
	-Document $document `
	-StartOffset 9 `
	-EndOffset 10 `
	-ReplacementText '2' `
	-ExpectedText '1' `
	-Reason 'Update the value'
Add-AstTextEdit -Document $document -TextEdit $edit

$result = Resolve-AstDocument -Document $document -PassThruText
$result.RenderedText
```

Use `New-AstTextEdit -Extent` when an `IScriptExtent` identifies the complete edit range.
`New-AstCollectionEdit` returns the same contract for token-aware collection removal. Batch
queueing validates expected text, ranges, overlaps, and same-offset insertions before queueing any
member. Conflict exceptions expose the existing and incoming edits through `ExistingEdit` and
`IncomingEdit` entries in `Exception.Data`. The offset and extent parameter sets on
`Add-AstTextEdit` remain convenience surfaces for one edit.

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

The current MVP replaces complete function definitions. It does not yet perform semantic renames
or body-only edits.

## Transactional Saves

`New-AstDocument -Path` records a SHA-256 fingerprint of the original bytes, the encoding/BOM,
and a path-bearing AST. `Save-AstDocument` preserves that encoding and existing newline
characters, validates rendered syntax, and stages output in the destination directory before
atomic replacement. It checks source and destination fingerprints after confirmation and
immediately before commit. It does not fall back to truncating the original if replacement fails.

Supported file encodings are valid BOM-less UTF-8 and BOM-marked UTF-8, UTF-16 LE/BE, and
UTF-32 LE/BE. Legacy code-page encodings are not inferred. In-memory documents require
`-OutPath` and default to UTF-8 without a BOM.

```powershell
$result = Save-AstDocument -Document $document -Confirm:$false
if ($result.ErrorRecord) {
    throw $result.ErrorRecord
}
$result.WasWritten
$result.WriteStatus
```

Expected validation and I/O failures return structured `AstEditor.WriteResult` objects with
`ErrorRecord` and `WasWritten = $false`. Check these fields before reporting success.
`-WhatIf` and declined confirmations also return non-written results. Temporary files owned
by the transaction are cleaned up on failure. Fingerprints protect the last pre-commit check,
not an OS-level compare-and-swap against a writer racing the replacement itself.

`Edit-PSFunction -Apply` uses this save contract. `Split-PSFunction` still has a separate
multi-file write workflow; it is not a transactional multi-file commit.

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

- AstEditor intentionally avoids mutating PowerShell AST objects in-place.
- It treats AST as a query surface and source of stable spans, while all changes are represented in an overlay plan.
