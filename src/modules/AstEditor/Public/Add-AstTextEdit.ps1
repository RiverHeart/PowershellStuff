using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Queues a validated text edit against an AstDocument source snapshot.

.DESCRIPTION
    Adds one zero-based, end-exclusive text edit to an AstDocument. The edit is
    validated against the document's immutable OriginalText and conflicts with
    previously queued edits are rejected.

    ExpectedText can be supplied as a stale-source guard. Its value must exactly
    match the source text in the requested range before the edit is queued.

.PARAMETER Document
    The AstDocument that owns the source snapshot and queued edits.

.PARAMETER StartOffset
    The zero-based start offset of the edit.

.PARAMETER EndOffset
    The zero-based, end-exclusive end offset of the edit.

.PARAMETER Extent
    A script extent whose offsets define the edit range.

.PARAMETER ReplacementText
    Text that replaces the selected range. Use an empty string for deletion.

.PARAMETER Reason
    A description identifying the edit for previews and conflict diagnostics.

.PARAMETER ExpectedText
    Source text expected in the selected range. Matching is case-sensitive.

.EXAMPLE
    Queue a text edit that replaces the characters at offsets 2 through 4 with 'ABC'
    and then resolve the document to apply the queued edits.

    $Document = New-AstDocument -InputObject '0123456789'
    $null = Add-AstTextEdit `
        -Document $Document `
        -StartOffset 2 `
        -EndOffset 5 `
        -ReplacementText 'ABC' `
        -Reason 'Replace [2, 5)'
    $Result = Resolve-AstDocument -Document $Document -PassThruText
#>
function Add-AstTextEdit {
    [CmdletBinding(DefaultParameterSetName = 'ByOffset')]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [int] $StartOffset,

        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [int] $EndOffset,

        [Parameter(Mandatory, ParameterSetName = 'ByExtent')]
        [IScriptExtent] $Extent,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ReplacementText,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Reason,

        [AllowEmptyString()]
        [string] $ExpectedText
    )

    $ResolvedStartOffset = if ($PSCmdlet.ParameterSetName -eq 'ByExtent') {
        $Extent.StartOffset
    } else {
        $StartOffset
    }
    $ResolvedEndOffset = if ($PSCmdlet.ParameterSetName -eq 'ByExtent') {
        $Extent.EndOffset
    } else {
        $EndOffset
    }

    if ($ResolvedStartOffset -lt 0) {
        throw 'StartOffset must be non-negative.'
    }
    if ($ResolvedEndOffset -lt $ResolvedStartOffset) {
        throw 'EndOffset must be greater than or equal to StartOffset.'
    }
    if ($ResolvedEndOffset -gt $Document.OriginalText.Length) {
        throw "EndOffset $ResolvedEndOffset exceeds document length $($Document.OriginalText.Length)."
    }

    $ActualText = $Document.OriginalText.Substring(
        $ResolvedStartOffset,
        $ResolvedEndOffset - $ResolvedStartOffset
    )
    if ($PSBoundParameters.ContainsKey('ExpectedText') -and $ActualText -cne $ExpectedText) {
        throw "Expected source text mismatch at offsets [$ResolvedStartOffset, $ResolvedEndOffset)."
    }

    $Document.ReplaceRange(
        $ResolvedStartOffset,
        $ResolvedEndOffset,
        $ReplacementText,
        $Reason
    )

    return [pscustomobject] @{
        PSTypeName = 'AstEditor.TextEditResult'
        Status = 'Queued'
        Path = $Document.Path
        StartOffset = $ResolvedStartOffset
        EndOffset = $ResolvedEndOffset
        ReplacementText = $ReplacementText
        Reason = $Reason
        ExpectedText = if ($PSBoundParameters.ContainsKey('ExpectedText')) {
            $ExpectedText
        } else {
            $null
        }
    }
}
