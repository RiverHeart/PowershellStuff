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

.EXAMPLE
    $doc = New-AstDocument -Path '.\ImageViewer.DSL.ps1'

    Parses an existing script file and returns a document that can receive edits.

.EXAMPLE
    $doc = New-AstDocument -InputObject 'Window Demo { }'

    Parses ad-hoc DSL text from memory for experimentation and tests.

.EXAMPLE
    $doc = New-AstDocument -InputObject { Window Demo { } }

    Uses a ScriptBlock input directly without an explicit parse step.

.EXAMPLE
    $tokens = $null
    $errors = $null
    $ast = [Parser]::ParseInput("Window Demo { }", [ref] $tokens, [ref] $errors)
    $doc = New-AstDocument -InputObject $ast

    Wraps an already parsed AST in a document.
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
        [ValidateNotNullOrEmpty()]
        [object] $InputObject
    )

    process {
        $Tokens = $null
        $Errors = $null

        if ($null -ne $InputObject -and $InputObject -is [AstDocument]) {
            return $InputObject
        }

        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
            $Snapshot = Get-AstFileSnapshot -Path $ResolvedPath
            $FileText = $Snapshot.Text
            $Ast = [Parser]::ParseInput($FileText, $ResolvedPath, [ref] $Tokens, [ref] $Errors)
            $NewLineSequence = if ($FileText.Contains("`r`n")) { "`r`n" } else { "`n" }
            $Document = [AstDocument]::new($ResolvedPath, $FileText, $Ast, $Tokens, $Errors)
            $Document.NewLineSequence = $NewLineSequence
            $Document.IsFileBacked = $true
            $Document.SourceEncoding = $Snapshot.Encoding
            $Document.OriginalFingerprint = $Snapshot.Fingerprint
            return $Document
        }

        if ($InputObject -is [string]) {
            $Text = [string] $InputObject
        } elseif ($InputObject -is [ScriptBlock]) {
            $Text = $InputObject.Ast.Extent.Text
        } elseif ($InputObject -is [Ast]) {
            $Text = ([Ast] $InputObject).Extent.Text
        } else {
            throw [System.ArgumentException]::new("Unsupported InputObject type '$($InputObject.GetType().FullName)'. Expected String, ScriptBlock, or Ast.")
        }

        $Ast = [Parser]::ParseInput($Text, [ref] $Tokens, [ref] $Errors)
        $NewLineSequence = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
        $Document = [AstDocument]::new('<memory>', $Text, $Ast, $Tokens, $Errors)
        $Document.NewLineSequence = $NewLineSequence
        return $Document
    }
}
