<#
.SYNOPSIS
    Creates a snapshot-backed script extent for an arbitrary source range.

.DESCRIPTION
    Returns an IScriptExtent with exact text, source-file provenance, and positions
    in the document's original snapshot.

    No AST node is required. Put another way, you do not need an existing AST
    node to reference any arbitrary range in the document.

    This is useful for creating extents for text ranges that are not directly
    represented by AST nodes, such as trailing whitespace or comments.

    Offsets are zero-based and end-exclusive; line and column numbers are one-based.
    This convention mirrors the behavior of standard PowerShell AST extents so
    no unnecessary conversions are required.

    CRLF, LF, and CR are recognized as line terminators. Position Line values
    include their terminators, and GetFullScript() returns the complete snapshot.
    Fragment documents reject ranges outside the submitted target. Empty ranges
    are permitted at either target endpoint. No edits are queued.

.NOTES
    ScriptExtents and Documents are deliberately detached. The extent describes
    *where*; the edit describes *what to change*. You connect the edit to a
    document explicitly when queuing it with Add-AstTextEdit.

.PARAMETER Document
    The AstDocument whose original snapshot owns the range.

.PARAMETER StartOffset
    The zero-based start offset in the complete snapshot, not the fragment text.

.PARAMETER EndOffset
    The zero-based, end-exclusive end offset in the complete snapshot.

.EXAMPLE
    Describe trailing spaces and create a detached deletion for that exact range
    so it can be trimmed from the document.

    $Document = New-AstDocument -InputObject '$Value = 1  '
    $Extent = New-AstScriptExtent -Document $Document -StartOffset 10 -EndOffset 12
    New-AstTextEdit `
        -Extent $Extent `
        -ReplacementText '' `
        -Reason 'Remove trailing whitespace.' |
        Add-AstTextEdit -Document $Document

    $Result = Resolve-AstDocument $Document -PassThruText

    Write-Host "Old: $($Document.OriginalText) ($($Document.OriginalText.Length)) "
    Write-Host "New: $($Result.RenderedText) ($($Result.RenderedText.Length))"
#>
function New-AstScriptExtent {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.IScriptExtent])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [AstDocument] $Document,

        [Parameter(Mandatory)]
        [int] $StartOffset,

        [Parameter(Mandatory)]
        [int] $EndOffset
    )

    if ($StartOffset -lt 0) {
        throw 'StartOffset must be non-negative.'
    }

    if ($EndOffset -lt $StartOffset) {
        throw 'EndOffset must be greater than or equal to StartOffset.'
    }

    if ($EndOffset -gt $Document.OriginalText.Length) {
        throw "EndOffset $EndOffset exceeds document length $($Document.OriginalText.Length)."
    }

    if ($Document.IsFragment -and
        ($StartOffset -lt $Document.Ast.Extent.StartOffset -or
        $EndOffset -gt $Document.Ast.Extent.EndOffset)
    ) {
        $Exception = [System.InvalidOperationException]::new(
            "Extent at offsets [$StartOffset, $EndOffset) falls outside the submitted fragment [$($Document.Ast.Extent.StartOffset), $($Document.Ast.Extent.EndOffset))."
        )
        $Exception.Data['FailureKind'] = 'OutsideTarget'
        throw $Exception
    }

    $Text = $Document.OriginalText
    $Lines = Get-AstTextLine -Text $Text
    $Positions = foreach ($Offset in $StartOffset, $EndOffset) {
        $LineIndex = Get-AstLineIndexFromOffset -LineRecords $Lines -Offset $Offset
        $Line = $Lines[$LineIndex]
        [AstScriptPosition]::new(
            $Document.Root.Ast.Extent.File,
            $Text,
            $Offset,
            $LineIndex + 1,
            $Offset - $Line.Start + 1,
            $Text.Substring($Line.Start, $Line.End - $Line.Start)
        )
    }

    return [AstScriptExtent]::new($Positions[0], $Positions[1])
}
