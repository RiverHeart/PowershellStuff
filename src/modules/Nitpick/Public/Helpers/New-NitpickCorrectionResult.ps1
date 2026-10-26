<#
.SYNOPSIS
    Constructs a correction envelope with separate proposal, application, and report data.

.DESCRIPTION
    Does not resolve corrections or write files. Arrays remain arrays even when empty
    or singleton. Rejects unknown statuses and contradictory lifecycle states rather
    than repairing them. A null proposal represents an uninitialized envelope or a
    target that could not be read. Validation does not freeze returned objects.

.PARAMETER Proposal
    The stable NitpickCorrectionProposal returned by Resolve-NitpickCorrectionProposal.
    Its Document is a mutable transaction handle, not an immutable diagnostic value;
    consumers must not modify queued edits between resolution and application.

.PARAMETER Application
    Status, CommittedCorrections, WriteResult, and ErrorRecord for application.
    Defaults to NotAttempted with no committed corrections or diagnostics.

.PARAMETER Report
    AnalysisSource, EffectiveText, EffectiveFindings, and
    FindingsWithCommittedCorrections. Defaults to no analysis and empty findings.
    AnalysisSource identifies the source analyzed by EffectiveFindings, not necessarily
    EffectiveText. Candidate text can accompany original findings without reanalysis.

.EXAMPLE
    New-NitpickCorrectionResult -Path $Path -Application @{
        Status = 'FailedRead'
        ErrorRecord = $_
    }
#>
function New-NitpickCorrectionResult {
    [CmdletBinding()]
    [OutputType('NitpickCorrectionResult')]
    param (
        [string] $Path = '<ScriptBlock>',

        [AllowNull()]
        [NitpickCorrectionProposal] $Proposal,

        [hashtable] $Application = @{},

        [hashtable] $Report = @{}
    )

    foreach ($Name in $Application.Keys) {
        if ($Name -notin 'Status', 'CommittedCorrections', 'WriteResult', 'ErrorRecord') {
            throw "Unknown Application property '$Name'."
        }
    }

    foreach ($Name in $Report.Keys) {
        if ($Name -notin 'AnalysisSource', 'EffectiveText', 'EffectiveFindings', 'FindingsWithCommittedCorrections') {
            throw "Unknown Report property '$Name'."
        }
    }

    $ApplicationStatus = if ($Application.ContainsKey('Status')) { $Application.Status } else { 'NotAttempted' }
    $AnalysisSource = if ($Report.ContainsKey('AnalysisSource')) { $Report.AnalysisSource } else { 'None' }

    if ($ApplicationStatus -isnot [string] -or
        $ApplicationStatus -notin @(
            'NotAttempted', 'Written', 'Preview', 'WhatIf', 'Declined', 'InMemory',
            'FailedValidation', 'StaleSource', 'StaleTarget', 'InvalidTarget',
            'FailedRead', 'FailedWrite'
        )
    ) {
        throw 'Application.Status must be a recognized application outcome.'
    }

    if ($AnalysisSource -isnot [string] -or
        $AnalysisSource -notin 'None', 'Original', 'Candidate'
    ) {
        throw 'Report.AnalysisSource must be None, Original, or Candidate.'
    }

    $ApplicationData = [NitpickCorrectionApplication]@{
        Status = $ApplicationStatus
        CommittedCorrections = @(
            if ($Application.ContainsKey('CommittedCorrections')) { $Application.CommittedCorrections }
        )
        WriteResult = $Application['WriteResult']
        ErrorRecord = $Application['ErrorRecord']
    }

    $ReportData = [NitpickCorrectionReport]@{
        AnalysisSource = $AnalysisSource
        EffectiveFindings = @(
            if ($Report.ContainsKey('EffectiveFindings')) { $Report.EffectiveFindings }
        )
        FindingsWithCommittedCorrections = @(
            if ($Report.ContainsKey('FindingsWithCommittedCorrections')) {
                $Report.FindingsWithCommittedCorrections
            }
        )
    }
    if ($null -ne $Report['EffectiveText']) {
        $ReportData.EffectiveText = $Report['EffectiveText']
    }
    $Result = [NitpickCorrectionResult]::new($Path, $Proposal, $ApplicationData, $ReportData)

    #--------------
    # VALIDATION
    #--------------

    if ($null -ne $Proposal -and (
            $Proposal.Status -isnot [string] -or
            $Proposal.Status -notin 'Ready', 'NoChanges', 'Rejected', 'FailedValidation'
        )
    ) {
        throw 'Proposal.Status must be Ready, NoChanges, Rejected, or FailedValidation.'
    }

    if ($AnalysisSource -eq 'None' -and (
            $null -ne $Result.Report.EffectiveText -or
            $Result.Report.EffectiveFindings.Count -gt 0 -or
            $Result.Report.FindingsWithCommittedCorrections.Count -gt 0
        )
    ) {
        throw 'A report with no analysis cannot contain effective text or findings.'
    }

    if ($null -eq $Proposal -and (
            $ApplicationStatus -notin 'NotAttempted', 'FailedRead' -or
            $AnalysisSource -ne 'None'
        )
    ) {
        throw 'Application and analysis require a proposal, except for an uninitialized envelope or FailedRead.'
    }

    if ($ApplicationStatus -eq 'FailedRead' -and (
            $null -ne $Proposal -or
            $null -eq $Result.Application.ErrorRecord -or
            $AnalysisSource -ne 'None'
        )
    ) {
        throw 'FailedRead requires an error, no proposal, and no report analysis.'
    }

    if ($null -ne $Proposal -and $Proposal.Status -ne 'Ready' -and
        $ApplicationStatus -ne 'NotAttempted'
    ) {
        throw 'Only a Ready proposal permits an application attempt.'
    }

    if (($Result.Application.CommittedCorrections.Count -gt 0 -or
        $Result.Report.FindingsWithCommittedCorrections.Count -gt 0) -and
        $ApplicationStatus -ne 'Written'
    ) {
        throw 'Committed corrections and their attributed findings require a Written application.'
    }

    if ($ApplicationStatus -eq 'Written') {
        $WriteResult = $Result.Application.WriteResult

        if ($Proposal.Status -ne 'Ready' -or
            $null -eq $WriteResult -or
            $WriteResult.WasWritten -ne $true -or
            $WriteResult.WriteStatus -ne 'Written'
        ) {
            throw 'Written requires a Ready proposal and a successful AstEditor write result.'
        }

        foreach ($Correction in $Result.Application.CommittedCorrections) {
            if ($Correction -notin $Proposal.AcceptedCorrections) {
                throw 'Committed corrections must belong to the proposal accepted corrections.'
            }
        }

        if ($Result.Report.FindingsWithCommittedCorrections.Count -gt 0 -and
            $Result.Application.CommittedCorrections.Count -eq 0) {
            throw 'Findings cannot be attributed to committed corrections when none were committed.'
        }
    }

    if ($AnalysisSource -eq 'Candidate' -and (
        $null -eq $Proposal -or
        $Proposal.WasReanalyzed -ne $true -or
        $Proposal.Status -notin 'Ready', 'NoChanges' -or
        $Proposal.ParseErrors.Count -gt 0 -or (
            $ApplicationStatus -notin 'Written', 'Preview', 'WhatIf', 'InMemory' -and
            -not ($ApplicationStatus -eq 'NotAttempted' -and $Proposal.Status -eq 'NoChanges')
        ))
    ) {
        throw 'Candidate analysis requires valid reanalysis and an outcome that permits candidate reporting.'
    }

    $Result
}
