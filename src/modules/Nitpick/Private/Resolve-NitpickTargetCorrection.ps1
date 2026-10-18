using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Applies or previews Fix corrections for one analyzed target and categorizes its findings.

.DESCRIPTION
    Returns the target's findings unchanged, with no CorrectionPreview, unless Fix is
    specified. When Fix is specified, resolves safe corrections against the target's
    immutable snapshot via Resolve-NitpickCorrection, writes them to disk through
    Save-AstDocument unless the document is in-memory, Preview is specified, or
    ShouldProcess declines, and reverts to the pre-fix findings when a write fails or is
    declined. Categorizes the target's findings into Fixed/Skipped/Conflicted/
    FailedValidation on the returned CorrectionPreview and accumulates the running
    Summary's fix-related counters.

.PARAMETER Fix
    Applies or previews corrections. Returns the original findings unchanged when omitted.

.PARAMETER Preview
    Resolves and reports corrections without writing them, even when Fix is specified.

.PARAMETER Document
    The AstDocument snapshot backing the target being corrected.

.PARAMETER Finding
    The target's complete finding set before correction.

.PARAMETER Rule
    The rules that applied to this target, used to resolve corrections.

.PARAMETER Ast
    The parsed Ast for the target, used to resolve the originating file path.

.PARAMETER Summary
    The running NitpickSummary for the invocation; its fix-related counters are updated
    directly, since NitpickSummary is a reference type.

.EXAMPLE
    Resolve-NitpickTargetCorrection -Fix -Document $Document -Finding $Findings `
        -Rule $Rules -Ast $Ast -Summary $Summary
#>
function Resolve-NitpickTargetCorrection {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [psobject] $Document,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [NitpickFinding[]] $Finding,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [NitpickRule[]] $Rule,

        [Parameter(Mandatory)]
        [Ast] $Ast,

        [Parameter(Mandatory)]
        [NitpickSummary] $Summary,

        [switch] $Fix,
        [switch] $Preview
    )

    $FinalFindings = $Finding
    $CorrectionPreview = $null

    if (-not $Fix) {
        return [pscustomobject]@{
            CorrectionPreview = $CorrectionPreview
            FinalFindings = $FinalFindings
        }
    }

    $ResolveParameters = @{
        Document = $Document
        Finding = $Finding
        Rule = $Rule
    }
    if ($Ast.Extent.File) {
        $ResolveParameters.Path = $Ast.Extent.File
    }

    $CorrectionPreview = Resolve-NitpickCorrection @ResolveParameters
    if (-not $CorrectionPreview.WasReanalyzed) {
        $CorrectionPreview.Findings.Final = $Finding
    }
    if ($CorrectionPreview.Corrections.Accepted.Count -gt 0) {
        if (-not $Document.IsFileBacked) {
            $CorrectionPreview.WriteStatus = 'InMemory'
        } elseif (-not $Preview) {
            if ($PSCmdlet.ShouldProcess($Document.Path, 'Apply Nitpick corrections')) {
                $WriteResult = Save-AstDocument `
                    -Document $Document `
                    -Confirm:$false `
                    -WhatIf:$false
                $CorrectionPreview.WriteResult = $WriteResult
                $CorrectionPreview.ErrorRecord = $WriteResult.ErrorRecord
                $CorrectionPreview.WriteStatus = $WriteResult.WriteStatus
                $CorrectionPreview.WasWritten = $WriteResult.WasWritten
                if ($WriteResult.WasWritten) {
                    $CorrectionPreview.Corrections.Fixed = $CorrectionPreview.Corrections.Accepted
                } else {
                    $CorrectionPreview.Corrections.Skipped = @($CorrectionPreview.Corrections.Skipped) + @(
                        foreach ($Correction in $CorrectionPreview.Corrections.Accepted) {
                            [pscustomobject]@{
                                Correction = $Correction
                                Reason = "Commit failed ($($WriteResult.WriteStatus)): $($WriteResult.ErrorRecord.Exception.Message)"
                            }
                        }
                    )
                    $CorrectionPreview.Findings.Final = $Finding
                    $CorrectionPreview.Findings.Remaining = $Finding
                    $CorrectionPreview.RenderedText = $Document.OriginalText
                    $CorrectionPreview.WasReanalyzed = $false
                }
            } else {
                $CorrectionPreview.WriteStatus = if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' }
                if (-not $WhatIfPreference) {
                    $CorrectionPreview.Findings.Final = $Finding
                    $CorrectionPreview.Findings.Remaining = $Finding
                    $CorrectionPreview.RenderedText = $Document.OriginalText
                    $CorrectionPreview.WasReanalyzed = $false
                }
            }
        }
    }
    $FinalFindings = if ($CorrectionPreview.WasReanalyzed) {
        $CorrectionPreview.Findings.Final
    } else {
        $Finding
    }
    $SkippedEdits = @($CorrectionPreview.Corrections.Skipped.Correction)
    $ConflictingEdits = @(
        $CorrectionPreview.Corrections.Conflicts.ExistingCorrection
        $CorrectionPreview.Corrections.Conflicts.IncomingCorrection
    )
    $FixedFindings = @($Finding | Where-Object {
        $Committed = @($_.Corrections | Where-Object {
            $_ -in $CorrectionPreview.Corrections.Fixed
        })
        $Committed.Count -gt 0
    })
    $SkippedFindings = @($Finding | Where-Object {
        @($_.Corrections | Where-Object { $_ -in $SkippedEdits }).Count -gt 0
    })
    $ConflictedFindings = @($Finding | Where-Object {
        @($_.Corrections | Where-Object { $_ -in $ConflictingEdits }).Count -gt 0
    })
    $FailedValidationFindings = if ($CorrectionPreview.WriteStatus -eq 'FailedValidation') {
        $Finding
    } else {
        @()
    }
    $CorrectionPreview.Findings.Fixed = $FixedFindings
    $CorrectionPreview.Findings.Skipped = $SkippedFindings
    $CorrectionPreview.Findings.Conflicted = $ConflictedFindings
    $CorrectionPreview.Findings.FailedValidation = @($FailedValidationFindings)
    $Summary.FixedFindingCount += $FixedFindings.Count
    $Summary.SkippedCorrectionCount += $CorrectionPreview.Corrections.Skipped.Count
    if ($CorrectionPreview.Corrections.Conflicts.Count -gt 0) {
        $Summary.ConflictedTargetCount++
    }
    if ($CorrectionPreview.WriteStatus -in 'FailedValidation', 'FailedWrite', 'StaleSource', 'StaleTarget', 'InvalidTarget') {
        $Summary.FailedTargetCount++
    }

    Write-Verbose (
        "Correction preview for '{0}': {1} accepted, {2} skipped." -f
        $CorrectionPreview.Path,
        $CorrectionPreview.Corrections.Accepted.Count,
        $CorrectionPreview.Corrections.Skipped.Count
    )
    foreach ($SkippedCorrection in $CorrectionPreview.Corrections.Skipped) {
        Write-Verbose (
            "Skipped correction from '{0}': {1}" -f
            $SkippedCorrection.Correction.RuleName,
            $SkippedCorrection.Reason
        )
    }

    [pscustomobject]@{
        CorrectionPreview = $CorrectionPreview
        FinalFindings = $FinalFindings
    }
}
