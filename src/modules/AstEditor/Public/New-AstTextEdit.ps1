using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Creates a detached text edit for an immutable source snapshot.

.DESCRIPTION
    Creates an AstEditor text edit without queueing it. Extent-based edits capture
    their source coordinates and expected text directly. Offset-based edits are
    validated against an AstDocument and derive their coordinates from its source.

.PARAMETER Document
    The AstDocument whose immutable source snapshot owns an offset-based edit.

.PARAMETER StartOffset
    The zero-based start offset of an offset-based edit.

.PARAMETER EndOffset
    The zero-based, end-exclusive end offset of an offset-based edit.

.PARAMETER Extent
    The script extent that defines an extent-based edit.

.PARAMETER ReplacementText
    Text that replaces the selected range. Use an empty string for deletion.

.PARAMETER Reason
    A description identifying the edit in previews and conflict diagnostics.

.PARAMETER ExpectedText
    Optional source text guard for an offset-based edit. Matching is case-sensitive.
#>
function New-AstTextEdit {
    [CmdletBinding(DefaultParameterSetName = 'ByExtent')]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
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

        [Parameter(ParameterSetName = 'ByOffset')]
        [AllowEmptyString()]
        [string] $ExpectedText
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByExtent') {
        return [pscustomobject] @{
            PSTypeName = 'AstEditor.TextEdit'
            StartLineNumber = $Extent.StartLineNumber
            EndLineNumber = $Extent.EndLineNumber
            StartColumnNumber = $Extent.StartColumnNumber
            EndColumnNumber = $Extent.EndColumnNumber
            StartOffset = $Extent.StartOffset
            EndOffset = $Extent.EndOffset
            ExpectedText = $Extent.Text
            ReplacementText = $ReplacementText
            Reason = $Reason
        }
    }

    if ($StartOffset -lt 0) {
        throw 'StartOffset must be non-negative.'
    }
    if ($EndOffset -lt $StartOffset) {
        throw 'EndOffset must be greater than or equal to StartOffset.'
    }
    if ($EndOffset -gt $Document.OriginalText.Length) {
        throw "EndOffset $EndOffset exceeds document length $($Document.OriginalText.Length)."
    }

    $ActualText = $Document.OriginalText.Substring($StartOffset, $EndOffset - $StartOffset)
    if ($PSBoundParameters.ContainsKey('ExpectedText') -and $ActualText -cne $ExpectedText) {
        throw "Expected source text mismatch at offsets [$StartOffset, $EndOffset)."
    }

    $Positions = foreach ($Offset in $StartOffset, $EndOffset) {
        $SourcePrefix = $Document.OriginalText.Substring(0, $Offset)
        $LineStartOffset = $SourcePrefix.LastIndexOf("`n")

        [pscustomobject] @{
            LineNumber = ([regex]::Matches($SourcePrefix, "`n")).Count + 1
            ColumnNumber = $Offset - $LineStartOffset
        }
    }

    return [pscustomobject] @{
        PSTypeName = 'AstEditor.TextEdit'
        StartLineNumber = $Positions[0].LineNumber
        EndLineNumber = $Positions[1].LineNumber
        StartColumnNumber = $Positions[0].ColumnNumber
        EndColumnNumber = $Positions[1].ColumnNumber
        StartOffset = $StartOffset
        EndOffset = $EndOffset
        ExpectedText = $ActualText
        ReplacementText = $ReplacementText
        Reason = $Reason
    }
}
