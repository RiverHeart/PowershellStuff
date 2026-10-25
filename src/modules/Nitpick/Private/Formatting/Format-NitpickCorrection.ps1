using namespace System.Collections.Generic

<#
.SYNOPSIS
    Formats one Nitpick correction result as console-friendly text.

.DESCRIPTION
    Formats the correction section that Start-Nitpicking -Fix writes for one target in
    text output: the proposal diff, labeled by the line:column where each correction
    starts, followed by a trailer stating the outcome once. Lines are indented to sit
    beneath the target header written by Format-NitpickText, which lets editors such
    as VS Code resolve each line:column against that header. The header itself and
    spacing between targets are left to the caller.

    Returns nothing when there is nothing worth reporting, meaning no accepted,
    committed, skipped, or conflicting corrections and no failure. Counts of accepted
    and committed corrections treat each change set as one correction.

.PARAMETER CorrectionResult
    The Nitpick.CorrectionResult for one target, as produced by
    New-NitpickCorrectionResult.

.EXAMPLE
    Format the correction result returned for one target.

    $CorrectionResult = Resolve-NitpickTargetCorrection -Preview `
        -Document $Document -Finding $Findings -Rule $Rules -Ast $Document.Ast
    Format-NitpickCorrection -CorrectionResult $CorrectionResult
#>
function Format-NitpickCorrection {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [psobject] $CorrectionResult
    )

    $Proposal = $CorrectionResult.Proposal
    $Application = $CorrectionResult.Application
    $ApplicationStatus = $Application.Status
    $ProposalStatus = if ($Proposal) { $Proposal.Status } else { 'Unavailable' }

    $AcceptedEditCount = if ($Proposal) { $Proposal.AcceptedCorrections.Count } else { 0 }
    $AcceptedCount = if ($Proposal) {
        Get-NitpickCorrectionCount -Corrections $Proposal.AcceptedCorrections
    } else {
        0
    }
    $CommittedCount = Get-NitpickCorrectionCount -Corrections $Application.CommittedCorrections
    $SkippedCount = if ($Proposal) { $Proposal.SkippedCorrections.Count } else { 0 }
    $ConflictCount = if ($Proposal) { $Proposal.Conflicts.Count } else { 0 }
    $HasFailure = $Application.ErrorRecord -or
        $ProposalStatus -in 'Rejected', 'FailedValidation' -or
        $ApplicationStatus -in @(
            'FailedRead', 'FailedValidation', 'StaleSource', 'StaleTarget', 'InvalidTarget', 'FailedWrite'
        )

    if ($AcceptedEditCount -eq 0 -and $CommittedCount -eq 0 -and
        $SkippedCount -eq 0 -and $ConflictCount -eq 0 -and -not $HasFailure
    ) {
        return
    }

    $Indent = '  '
    $Lines = [List[string]]::new()
    if ($AcceptedEditCount -gt 0 -and $Proposal.Diff) {
        foreach ($Line in ([string] $Proposal.Diff) -split '\r?\n') {
            $Lines.Add($(if ($Line) { "$Indent$Line" } else { '' }))
        }
        $Lines.Add('')
    }

    $CorrectionNoun = if ($AcceptedCount -eq 1) { 'correction' } else { 'corrections' }
    $IsCleanOutcome = $AcceptedEditCount -gt 0 -and
        $SkippedCount -eq 0 -and $ConflictCount -eq 0 -and -not $HasFailure

    $Trailer = if ($IsCleanOutcome) {
        # Preview and WhatIf share wording: "proposed" already implies the file is unchanged.
        switch ($ApplicationStatus) {
            'Preview' { '{0} proposed {1}.' -f $AcceptedCount, $CorrectionNoun }
            'WhatIf' { '{0} proposed {1}.' -f $AcceptedCount, $CorrectionNoun }
            'Declined' { '{0} proposed {1} declined.' -f $AcceptedCount, $CorrectionNoun }
            'InMemory' { '{0} {1} applied in memory.' -f $AcceptedCount, $CorrectionNoun }
            'Written' {
                $CommittedNoun = if ($CommittedCount -eq 1) { 'correction' } else { 'corrections' }
                '{0} {1} applied.' -f $CommittedCount, $CommittedNoun
            }
        }
    }
    if (-not $Trailer) {
        $SkippedNoun = if ($SkippedCount -eq 1) { 'edit' } else { 'edits' }
        $ConflictNoun = if ($ConflictCount -eq 1) { 'conflict' } else { 'conflicts' }
        $Trailer = '{0} corrections committed, {1} corrections accepted, {2} {3} skipped, {4} {5} (proposal: {6}; application: {7}).' -f
            $CommittedCount, $AcceptedCount, $SkippedCount, $SkippedNoun,
            $ConflictCount, $ConflictNoun, $ProposalStatus, $ApplicationStatus
    }
    $Lines.Add("$Indent$Trailer")

    Write-Output ($Lines -join [Environment]::NewLine)
}
