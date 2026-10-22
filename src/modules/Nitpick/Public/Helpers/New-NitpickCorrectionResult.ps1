<#
.SYNOPSIS
    Constructs a correction envelope with separate proposal, application, and report data.

.DESCRIPTION
    Does not resolve corrections or write files. Arrays remain arrays even when empty
    or singleton. A null proposal represents a target that could not be read.

.PARAMETER Proposal
    The stable Nitpick.CorrectionProposal returned by Resolve-NitpickCorrection.

.PARAMETER Application
    Status, CommittedCorrections, WriteResult, and ErrorRecord for application.
    Defaults to NotAttempted with no committed corrections or diagnostics.

.PARAMETER Report
    AnalysisSource, EffectiveText, EffectiveFindings, and
    FindingsWithCommittedCorrections. Defaults to no analysis and empty findings.

.EXAMPLE
    New-NitpickCorrectionResult -Path $Path -Application @{
        Status = 'FailedRead'
        ErrorRecord = $_
    }
#>
function New-NitpickCorrectionResult {
    [CmdletBinding()]
    [OutputType('Nitpick.CorrectionResult')]
    param (
        [string] $Path = '<ScriptBlock>',

        [AllowNull()]
        [psobject] $Proposal,

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

    [pscustomobject]@{
        PSTypeName = 'Nitpick.CorrectionResult'
        Path = $Path
        Proposal = $Proposal
        Application = [pscustomobject]@{
            Status = if ($Application.ContainsKey('Status')) { $Application.Status } else { 'NotAttempted' }
            CommittedCorrections = @(
                if ($Application.ContainsKey('CommittedCorrections')) { $Application.CommittedCorrections }
            )
            WriteResult = $Application['WriteResult']
            ErrorRecord = $Application['ErrorRecord']
        }

        Report = [pscustomobject]@{
            AnalysisSource = if ($Report.ContainsKey('AnalysisSource')) { $Report.AnalysisSource } else { 'None' }
            EffectiveText = $Report['EffectiveText']
            EffectiveFindings = @(
                if ($Report.ContainsKey('EffectiveFindings')) { $Report.EffectiveFindings }
            )
            FindingsWithCommittedCorrections = @(
                if ($Report.ContainsKey('FindingsWithCommittedCorrections')) {
                    $Report.FindingsWithCommittedCorrections
                }
            )
        }
    }
}
