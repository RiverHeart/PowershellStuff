using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Queues a validated text edit against an AstDocument source snapshot.

.DESCRIPTION
    Atomically validates and queues one or more detached edits against an
    AstDocument. Every edit is checked against the document's immutable
    OriginalText before any edit is queued. Conflicts with previously queued
    edits or other members of the supplied batch reject the complete batch.

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

.PARAMETER TextEdit
    One or more detached AstEditor.TextEdit objects to validate and queue atomically.

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

        [Parameter(Mandatory, ParameterSetName = 'ByTextEdit', ValueFromPipeline)]
        [ValidateScript({ $_.PSTypeNames -contains 'AstEditor.TextEdit' })]
        [psobject[]] $TextEdit,

        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [Parameter(Mandatory, ParameterSetName = 'ByExtent')]
        [AllowEmptyString()]
        [string] $ReplacementText,

        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [Parameter(Mandatory, ParameterSetName = 'ByExtent')]
        [ValidateNotNullOrEmpty()]
        [string] $Reason,

        [Parameter(ParameterSetName = 'ByOffset')]
        [Parameter(ParameterSetName = 'ByExtent')]
        [AllowEmptyString()]
        [string] $ExpectedText
    )

    $Edits = if ($PSCmdlet.ParameterSetName -eq 'ByTextEdit') {
        @($TextEdit)
    } else {
        $NewEditParameters = @{
            ReplacementText = $ReplacementText
            Reason = $Reason
        }
        if ($PSCmdlet.ParameterSetName -eq 'ByExtent') {
            $NewEditParameters.Extent = $Extent
            if ($PSBoundParameters.ContainsKey('ExpectedText') -and $Extent.Text -cne $ExpectedText) {
                throw "Expected source text mismatch at offsets [$($Extent.StartOffset), $($Extent.EndOffset))."
            }
        } else {
            $NewEditParameters.Document = $Document
            $NewEditParameters.StartOffset = $StartOffset
            $NewEditParameters.EndOffset = $EndOffset
            if ($PSBoundParameters.ContainsKey('ExpectedText')) {
                $NewEditParameters.ExpectedText = $ExpectedText
            }
        }

        @(New-AstTextEdit @NewEditParameters)
    }

    $ValidatedEdits = [System.Collections.Generic.List[psobject]]::new()
    foreach ($Edit in $Edits) {
        if ($Edit.StartOffset -lt 0) {
            throw 'StartOffset must be non-negative.'
        }
        if ($Edit.EndOffset -lt $Edit.StartOffset) {
            throw 'EndOffset must be greater than or equal to StartOffset.'
        }
        if ($Edit.EndOffset -gt $Document.OriginalText.Length) {
            throw "EndOffset $($Edit.EndOffset) exceeds document length $($Document.OriginalText.Length)."
        }

        $ActualText = $Document.OriginalText.Substring(
            $Edit.StartOffset,
            $Edit.EndOffset - $Edit.StartOffset
        )
        if ($ActualText -cne $Edit.ExpectedText) {
            $Message = "Expected source text mismatch at offsets [$($Edit.StartOffset), $($Edit.EndOffset))."
            $Exception = [InvalidOperationException]::new($Message)
            $Exception.Data['FailureKind'] = 'ExpectedTextMismatch'
            $Exception.Data['IncomingEdit'] = $Edit
            throw $Exception
        }

        foreach ($ExistingEdit in @($Document.Edits) + $ValidatedEdits.ToArray()) {
            $HasSharedInsertionOffset =
                $ExistingEdit.StartOffset -eq $ExistingEdit.EndOffset -and
                $Edit.StartOffset -eq $Edit.EndOffset -and
                $ExistingEdit.StartOffset -eq $Edit.StartOffset
            $Overlaps =
                $ExistingEdit.StartOffset -lt $Edit.EndOffset -and
                $Edit.StartOffset -lt $ExistingEdit.EndOffset

            if ($Overlaps -or $HasSharedInsertionOffset) {
                $Message = "Edit conflict detected between '$($ExistingEdit.Reason)' at offsets [$($ExistingEdit.StartOffset), $($ExistingEdit.EndOffset)) and '$($Edit.Reason)' at offsets [$($Edit.StartOffset), $($Edit.EndOffset))."
                $Exception = [InvalidOperationException]::new($Message)
                $Exception.Data['FailureKind'] = 'Conflict'
                $Exception.Data['ExistingEdit'] = $ExistingEdit
                $Exception.Data['IncomingEdit'] = $Edit
                throw $Exception
            }
        }

        $ValidatedEdits.Add($Edit)
    }

    foreach ($Edit in $ValidatedEdits) {
        $Document.ReplaceRange(
            $Edit.StartOffset,
            $Edit.EndOffset,
            $Edit.ReplacementText,
            $Edit.Reason
        )
    }

    foreach ($Edit in $ValidatedEdits) {
        [pscustomobject] @{
            PSTypeName = 'AstEditor.TextEditResult'
            Status = 'Queued'
            Path = $Document.Path
            TextEdit = $Edit
            StartOffset = $Edit.StartOffset
            EndOffset = $Edit.EndOffset
            ReplacementText = $Edit.ReplacementText
            Reason = $Edit.Reason
            ExpectedText = $Edit.ExpectedText
        }
    }
}
