using namespace System

<#
.SYNOPSIS
    Formats one Nitpick correction result as console-friendly text.

.DESCRIPTION
    Formats the correction block that Start-Nitpicking -Fix writes for one target in
    text output: a status-aware heading naming the target, the proposal diff, and a
    trailer summarizing the outcome. Spacing between blocks is left to the caller.

    Returns nothing when there is nothing worth reporting, meaning no accepted,
    committed, skipped, or conflicting corrections and no failure. Counts of accepted
    and committed corrections treat each change set as one correction.

    The target path in the heading uses an ANSI OSC 8 hyperlink when appropriate; see
    Format-NitpickHyperlink.

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

    $Path = if ($CorrectionResult.Path) { $CorrectionResult.Path } else { '<ScriptBlock>' }
    $FileUri = $null
    $PathText = if ([Uri]::TryCreate($Path, [UriKind]::Absolute, [ref] $FileUri) -and $FileUri.IsFile) {
        Format-NitpickHyperlink -Uri $FileUri -Text $Path
    } else {
        $Path
    }

    $IsCleanOutcome = $AcceptedEditCount -gt 0 -and
        $SkippedCount -eq 0 -and $ConflictCount -eq 0 -and -not $HasFailure

    $StatusHeading = if ($IsCleanOutcome) {
        switch ($ApplicationStatus) {
            'Preview' { 'Proposed corrections for {0} (preview):' }
            'WhatIf' { 'Proposed corrections for {0} (WhatIf):' }
            'Written' { 'Applied corrections for {0}:' }
            'InMemory' { 'Proposed corrections for {0} (in-memory):' }
            'Declined' { 'Proposed corrections for {0} (not applied):' }
        }
    }
    if (-not $StatusHeading) {
        $StatusHeading = 'Corrections for {0} (proposal: {1}; application: {2}):'
    }
    Write-Output ($StatusHeading -f $PathText, $ProposalStatus, $ApplicationStatus)

    if ($AcceptedEditCount -gt 0) {
        Write-Output $Proposal.Diff
    }

    $CorrectionNoun = if ($AcceptedCount -eq 1) { 'correction' } else { 'corrections' }
    $Trailer = if ($IsCleanOutcome) {
        switch ($ApplicationStatus) {
            'Preview' { '{0} proposed {1}. No files changed (preview).' -f $AcceptedCount, $CorrectionNoun }
            'WhatIf' { '{0} proposed {1}. No files changed (WhatIf).' -f $AcceptedCount, $CorrectionNoun }
            'Written' { '{0} {1} applied.' -f $CommittedCount, $CorrectionNoun }
            'InMemory' {
                '{0} proposed {1} applied to in-memory text only.' -f $AcceptedCount, $CorrectionNoun
            }
            'Declined' { '{0} proposed {1} were not applied.' -f $AcceptedCount, $CorrectionNoun }
        }
    } else {
        $SkippedNoun = if ($SkippedCount -eq 1) { 'edit' } else { 'edits' }
        $ConflictNoun = if ($ConflictCount -eq 1) { 'conflict' } else { 'conflicts' }
        '{0} corrections committed, {1} corrections accepted, {2} {3} skipped, {4} {5}.' -f
            $CommittedCount, $AcceptedCount, $SkippedCount, $SkippedNoun,
            $ConflictCount, $ConflictNoun
    }

    Write-Output "`n$Trailer"
}
