using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Resolves, applies, and reports corrections for one analyzed target.

.DESCRIPTION
    Owns ShouldProcess and application policy, not proposal facts or summary counters.
    Preview, WhatIf, and in-memory targets expose valid candidate text. Declined or
    failed writes expose the original snapshot while retaining the complete proposal.
    Candidate findings are used only when reanalysis is available.

.PARAMETER Document
    The AstDocument snapshot backing the target.

.PARAMETER Finding
    The complete original finding set.

.PARAMETER Rule
    Selected rules to rerun against candidate text.

.PARAMETER Ast
    Original AST retaining source path context.

.PARAMETER FixMode
    Controls whether corrections are previewed, guided, or applied. Guided supplies
    Select-NitpickGuidedCorrection as the proposal's CorrectionSelector and otherwise
    applies like Apply.

.EXAMPLE
    Resolves, applies, and reports corrections for one analyzed target.

    Resolve-NitpickTargetCorrection `
        -Document $Document `
        -Finding $Findings `
        -Rule $Rules `
        -FixMode 'Preview'
#>
function Resolve-NitpickTargetCorrection {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('NitpickCorrectionResult')]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [NitpickFinding[]] $Finding,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [NitpickRule[]] $Rule,

        [Parameter(Mandatory)]
        [ValidateSet('Preview', 'Guided', 'Apply')]
        [string] $FixMode
    )

    $Preview = $FixMode -eq 'Preview'
    $ResolveParameters = @{
        Document = $Document
        Finding = $Finding
        Rule = $Rule
    }

    if ($FixMode -eq 'Guided') {
        $ResolveParameters.CorrectionSelector = {
            param($Finding, $Corrections, $Document)
            Select-NitpickGuidedCorrection `
                -Finding $Finding `
                -Correction $Corrections `
                -Document $Document
        }
    }

    $Proposal = Resolve-NitpickCorrectionProposal @ResolveParameters

    $Application = @{ Status = 'NotAttempted' }
    if ($Proposal.Status -eq 'Ready') {
        if ($Preview) {
            $Application.Status = 'Preview'
        } elseif (-not $Document.IsFileBacked) {
            $Application.Status = 'InMemory'
            $Application.AppliedCorrections = $Proposal.AcceptedCorrections
        } elseif ($PSCmdlet.ShouldProcess($Document.Path, 'Apply Nitpick corrections')) {
            $WriteResult = Save-AstDocument -Document $Document -Confirm:$false -WhatIf:$false

            $Application.Status = $WriteResult.WriteStatus
            $Application.WriteResult = $WriteResult
            $Application.ErrorRecord = $WriteResult.ErrorRecord

            if ($WriteResult.WasWritten) {
                $Application.AppliedCorrections = $Proposal.AcceptedCorrections
            }
        } else {
            $Application.Status = if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' }
        }
    }

    $UseCandidateText =
        $Proposal.Status -eq 'NoChanges' -or
        $Application.Status -in 'InMemory', 'Preview', 'WhatIf', 'Written'

    $UseCandidateFindings = $UseCandidateText -and $Proposal.WasReanalyzed

    # Attribution: a finding belongs to a list when any of its corrections is in that list.
    $SelectFindingsWithCorrections = {
        param ([NitpickCorrection[]] $Corrections)

        foreach ($OriginalFinding in $Proposal.OriginalFindings) {
            foreach ($Correction in $OriginalFinding.Corrections) {
                if ($Correction -in $Corrections) {
                    $OriginalFinding
                    break
                }
            }
        }
    }

    $Report = @{
        AnalysisSource = if ($UseCandidateFindings) { 'Candidate' } else { 'Original' }
        EffectiveText = if ($Document.IsFragment) {
            if ($UseCandidateText) { $Proposal.CandidateFragmentText } else { $Proposal.OriginalFragmentText }
        } else {
            if ($UseCandidateText) { $Proposal.CandidateText } else { $Proposal.OriginalText }
        }
        EffectiveFindings = if ($UseCandidateFindings) {
            $Proposal.CandidateFindings
        } else {
            $Proposal.OriginalFindings
        }

        FindingsWithAppliedCorrections = @(& $SelectFindingsWithCorrections $Application.AppliedCorrections)
        FindingsWithAcceptedCorrections = @(& $SelectFindingsWithCorrections $Proposal.AcceptedCorrections)
    }

    Write-Verbose (
        "Correction proposal for '{0}': {1}; {2} accepted, {3} findings skipped, {4} undecided; application: {5}." -f
        $Proposal.Path, $Proposal.Status, $Proposal.AcceptedCorrections.Count,
        $Proposal.SkippedFindings.Count, $Proposal.UndecidedFindings.Count, $Application.Status
    )

    foreach ($SkippedCorrection in $Proposal.SkippedCorrections) {
        Write-Verbose (
            "Skipped correction from '{0}': {1}" -f
            (Get-NitpickRuleLabel -InputObject $SkippedCorrection.Correction),
            $SkippedCorrection.Reason
        )
    }

    New-NitpickCorrectionResult `
        -Path $Proposal.Path `
        -Proposal $Proposal `
        -Application $Application `
        -Report $Report
}
