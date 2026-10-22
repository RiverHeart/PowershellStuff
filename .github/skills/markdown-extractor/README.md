# Markdown extractor

Dot-source `scripts\Get-MarkdownSection.ps1` to load the commands.

```powershell
. .\.github\skills\markdown-extractor\scripts\Get-MarkdownSection.ps1

$Document = New-MarkdownDocument -Path .\README.md
$Document.Sections                    # Top-level sections, with nested Sections
$Document.GetSections()               # All sections in document order

Get-MarkdownSection -Path .\README.md -Name
Get-MarkdownSection -Path .\README.md -Section overview -Content
Get-MarkdownSection -Path .\README.md -Section overview -RawContent
```

`New-MarkdownDocument` returns one `MarkdownDocument`, not an enumeration of its
sections. It also accepts `-Text` for in-memory Markdown. `Get-MarkdownSection`
returns a flattened list by default, or filters it by case-insensitive slug.
Duplicate slugs produce a warning and return the first match when filtering.

A section's `Content` stores only its direct body lines, ending at the next
heading of any depth. Child sections are stored separately in `Sections`.
`GetContent()` recursively renders the body, including descendant headings and
bodies but excluding the section's own heading. The command's `-Content` and
`-RawContent` options use this recursive rendering, so parent extraction still
includes the complete subtree.

`LineStart` is the line after the heading; `LineEnd` is the inclusive end of the
direct content, and can precede `LineStart` for an empty body. These are source
coordinates captured during parsing, not updated after edits. `ContentLineCount`
reflects the current direct content count. `Depth` and `Section` (the slug) also
describe the parsed heading; changing `Header` does not recompute them.

The parser recognizes ATX headings (`#` through `######`) and ignores headings
inside triple-backtick code fences. It is not a complete CommonMark parser.

For direct use, documents expose `ParseFile()`, `ParseString()`, and
`ParseStream(TextReader)` methods. Each parse replaces the document's previous
sections. `ParseStream(TextReader, MaxDepth)` limits heading discovery (0 means
all levels); deeper headings remain in ancestor content. Supplied readers are
consumed but not closed; file and string readers created internally are disposed.

`ToString()` walks the current tree: document `Preamble` first, then each heading,
its direct content, and its children in list order. `Save(Path)` writes that result
as UTF-8 without a BOM. Both reflect content edits, header edits, and section
removals or reordering without duplicating child content.

Blank lines and the parsed document's final-newline presence are retained.
Newlines are normalized to the platform's newline; source encoding and mixed
newline styles are not preserved. `Header` contains the full heading, including
its hashes; changing tree depth does not automatically rewrite those hashes.

```powershell
$Document = New-MarkdownDocument -Path .\README.md
$Section = $Document.GetSections() | Where-Object Section -eq overview
$Section.Content[0] = $Section.Content[0].Replace('old text', 'new text')
$Document.Save((Join-Path $PWD 'README.md'))
```

Run the focused tests through the repository runner:

```powershell
.\tools\Invoke-Test.ps1 -Suite MarkdownExtractor
```

## Possible future editing support

The document model could later support structural editing:

* Edit-MarkdownSection (as opposed to patching)
* Remove-MarkdownSection
* Add-MarkdownSection (append or insert)
* Find-MarkdownSection (find sections with relevant text)
