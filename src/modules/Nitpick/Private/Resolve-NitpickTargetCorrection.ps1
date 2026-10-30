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

.PARAMETER Preview
    Reports candidate corrections without writing.

.EXAMPLE
    Resolve-NitpickTargetCorrection -Document $Document -Finding $Findings `
        -Rule $Rules -Ast $Ast -Preview
#>
function Resolve-NitpickTargetCorrection {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('NitpickCorrectionResult')]
    param (
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

        [switch] $Preview
    )

    $ResolveParameters = @{
        Document = $Document
        Finding = $Finding
        Rule = $Rule
    }
    if ($Ast.Extent.File) {
        $ResolveParameters.Path = $Ast.Extent.File
    }
    $Proposal = Resolve-NitpickCorrectionProposal @ResolveParameters

    $Application = @{ Status = 'NotAttempted' }
    if ($Proposal.Status -eq 'Ready') {
        if ($Preview) {
            $Application.Status = 'Preview'
        } elseif (-not $Document.IsFileBacked) {
            $Application.Status = 'InMemory'
        } elseif ($PSCmdlet.ShouldProcess($Document.Path, 'Apply Nitpick corrections')) {
            $WriteResult = Save-AstDocument -Document $Document -Confirm:$false -WhatIf:$false
            $Application.Status = $WriteResult.WriteStatus
            $Application.WriteResult = $WriteResult
            $Application.ErrorRecord = $WriteResult.ErrorRecord
            if ($WriteResult.WasWritten) {
                $Application.CommittedCorrections = $Proposal.AcceptedCorrections
            }
        } else {
            $Application.Status = if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' }
        }
    }

    $UseCandidateText = $Proposal.Status -eq 'NoChanges' -or
        $Application.Status -in 'InMemory', 'Preview', 'WhatIf', 'Written'
    $UseCandidateFindings = $UseCandidateText -and $Proposal.WasReanalyzed
    $Report = @{
        AnalysisSource = if ($UseCandidateFindings) { 'Candidate' } else { 'Original' }
        EffectiveText = if ($UseCandidateText) { $Proposal.CandidateText } else { $Proposal.OriginalText }
        EffectiveFindings = if ($UseCandidateFindings) {
            $Proposal.CandidateFindings
        } else {
            $Proposal.OriginalFindings
        }

        FindingsWithCommittedCorrections = @(
            foreach ($OriginalFinding in $Proposal.OriginalFindings) {
                foreach ($Correction in $OriginalFinding.Corrections) {
                    if ($Correction -in $Application.CommittedCorrections) {
                        $OriginalFinding
                        break
                    }
                }
            }
        )
    }

    Write-Verbose (
        "Correction proposal for '{0}': {1}; {2} accepted, {3} skipped; application: {4}." -f
        $Proposal.Path, $Proposal.Status, $Proposal.AcceptedCorrections.Count,
        $Proposal.SkippedCorrections.Count, $Application.Status
    )

    foreach ($SkippedCorrection in $Proposal.SkippedCorrections) {
        Write-Verbose (
            "Skipped correction from '{0}': {1}" -f
            (Get-NitpickRuleLabel -InputObject $SkippedCorrection.Correction), $SkippedCorrection.Reason
        )
    }

    New-NitpickCorrectionResult -Path $Proposal.Path -Proposal $Proposal `
        -Application $Application -Report $Report
}
