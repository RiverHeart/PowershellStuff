using namespace System
using namespace System.IO
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Parses script content into an AstDocument ready to receive edits.

.DESCRIPTION
    Creates an AstDocument from a file path, string text, ScriptBlock, or already
    parsed Ast via the InputObject parameter. The returned object keeps the original
    source text, parse tokens, parse errors, and an edit list that can collect
    text edits without mutating AST nodes. This is the entry point for the
    immutable-AST + overlay workflow. File inputs capture a byte fingerprint and
    source encoding for transactional saves. BOM-less input must be valid UTF-8;
    BOM-marked UTF-8, UTF-16, and UTF-32 are also supported.
    ScriptBlock and Ast inputs reparse their complete parse-time source snapshot.
    Ast is the submitted node located in that snapshot by type, offsets, and depth;
    Root groups the complete snapshot's typed Ast, Tokens, and ParseErrors.
    IsFragment distinguishes a submitted node
    from the root, even when both cover the same text. These inputs remain in-memory
    documents: Extent.File is provenance, not permission to save to that file.
    OriginalText and all offsets refer to the snapshot. Tokens contains only tokens
    inside Ast.Extent; Root.Tokens contains all snapshot tokens. ParseErrors omits
    only errors positioned strictly before the fragment start; Root.ParseErrors
    contains every snapshot error. No render-validation errors are filtered.
    When GetFullScript() is null, extent text is parsed as standalone input.
    SourceExtent, HasSourceProvenance, and GetSourcePosition are transitional APIs;
    GetSourcePosition now looks up a snapshot offset without shifting it.
    Strings have no inferred call-site provenance.

.EXAMPLE
    $doc = New-AstDocument -Path '.\ImageViewer.DSL.ps1'

    Parses an existing script file and returns a document that can receive edits.

.EXAMPLE
    $doc = New-AstDocument -InputObject 'Window Demo { }'

    Parses ad-hoc DSL text from memory for experimentation and tests.

.EXAMPLE
    $doc = New-AstDocument -InputObject { Window Demo { } }

    Parses the ScriptBlock's source snapshot and selects its fragment node.

.EXAMPLE
    $tokens = $null
    $errors = $null
    $ast = [Parser]::ParseInput("Window Demo { }", [ref] $tokens, [ref] $errors)
    $doc = New-AstDocument -InputObject $ast

    Parses the supplied AST's snapshot and selects the corresponding node.
#>
function New-AstDocument {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType('AstDocument')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [object] $InputObject
    )

    process {
        if ($null -ne $InputObject -and $InputObject -is [AstDocument]) {
            return $InputObject
        }

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
            $Snapshot = Get-AstFileSnapshot -Path $ResolvedPath
            $Document = [AstDocument]::new($ResolvedPath, $Snapshot.Text)
            $Document.IsFileBacked = $true
            $Document.SourceEncoding = $Snapshot.Encoding
            $Document.OriginalFingerprint = $Snapshot.Fingerprint
            return $Document
        }

        if ($InputObject -is [string] -or $InputObject -is [ScriptBlock] -or $InputObject -is [Ast]) {
            return [AstDocument]::new($InputObject)
        }

        $TypeName = if ($null -eq $InputObject) { '<null>' } else { $InputObject.GetType().FullName }
        throw [ArgumentException]::new("Unsupported InputObject type '$TypeName'. Expected String, ScriptBlock, or Ast.")
    }
}
