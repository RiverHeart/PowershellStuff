using namespace System.Collections.Generic
using module AstEditor

<#
.SYNOPSIS
    Resolves a native Nitpick correction proposal against one source snapshot.

.DESCRIPTION
    Selects safe corrections and delegates atomic source validation and queueing to
    AstEditor. A correction is one complete fix for a finding: its text edits are queued
    together and applied all-or-nothing. Only Safe corrections are selected, and at most
    one per finding; a finding proposing several Safe corrections has all of its
    corrections skipped, because automatic selection never chooses between alternatives.

    If the selected batch is stale or conflicting, AstEditor rejects it without queueing any
    member. Returns a stable proposal containing candidate text, validation diagnostics,
    and candidate findings when rules are supplied. Application never changes these
    facts; a proposal does not claim that edits were written.

    Diff includes navigable line:column reason headers and caret rows
    beneath removed and added edit spans. Multiline spans annotate their first
    line only; carets reflect queued ranges rather than minimal text differences.

    Execution attribution is retained from the supplied findings and corrections.
    Candidate reanalysis assigns identity through NitpickRule.Invoke. Direct standalone
    findings require qualified RuleId; detached corrections may omit identity.

.PARAMETER Script
    The exact source snapshot from which the correction offsets were calculated.

.PARAMETER Document
    The AstEditor document analyzed by Nitpick. Its snapshot and queued transaction
    are retained in the result so preview and file application use the same edits.
    This is a mutable transaction handle: consumers must not modify its queued edits
    between resolution and application. Proposal diagnostics are stable by ownership.

.PARAMETER Finding
    Native Nitpick findings containing corrections produced from the source snapshot.

.PARAMETER Rule
    Selected Nitpick rules to rerun against valid rendered text. When omitted, the
    correction preview is returned without final reanalysis.

.PARAMETER Path
    Optional source path used to retain file identity during final rule analysis.

.EXAMPLE
    $Result = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Finding
    $Result.CandidateText

    Previews all independent safe corrections attached to the findings. Each finding's
    single Safe correction is evaluated as one unit, and all accepted corrections are
    rendered against the original source snapshot in one pass.

.EXAMPLE
    $Edits = @(
        New-AstTextEdit `
            -Extent $FirstExtent `
            -ReplacementText '$First = 2' `
            -Reason 'Replace the coupled assignments.'

        New-AstTextEdit `
            -Extent $SecondExtent `
            -ReplacementText '$Second = 3' `
            -Reason 'Replace the coupled assignments.'
    )
    $Correction = New-NitpickCorrection `
        -TextEdit $Edits `
        -FilePathOrContext '<ScriptBlock>' `
        -Description 'Replace the coupled assignments.'
    $Result = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Finding

    When $Finding carries $Correction, both of its edits are accepted or skipped together.
    For example, stale expected text on either edit skips the complete correction.

.EXAMPLE
    Inspect conflicts when independent change sets overlap. Under the target-level conflict
    policy, an overlap rejects the complete preview batch and leaves candidate text unchanged.

    $Result = Resolve-NitpickCorrectionProposal -Script $Source -Finding $Finding
    $Result.Conflicts
    $Result.CandidateText -eq $Source

.EXAMPLE
    Returns candidate findings after applying the selected rules to the source snapshot.

    $Result = Resolve-NitpickCorrectionProposal `
        -Script $Source `
        -Finding $Finding `
        -Rule $SelectedRules
    $Result.CandidateFindings
#>
function Resolve-NitpickCorrectionProposal {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseOutputTypeCorrectly', '')]
    [OutputType('NitpickCorrectionProposal')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Script')]
        [AllowEmptyString()]
        [string] $Script,

        [Parameter(Mandatory, ParameterSetName = 'Document')]
        [AstDocument] $Document,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [NitpickFinding[]] $Finding,

        [NitpickRule[]] $Rule,

        [AllowNull()]
        [string] $Path
    )

    if ($Document.IsFileBacked -and $Path) {
        Write-Warning "Both `-Path` and a file-backed `-Document` are specified. The `-Path` parameter will be ignored."
    }

    if ($PSCmdlet.ParameterSetName -eq 'Script') {
        $Document = New-AstDocument -InputObject $Script
    } else {
        $Script = $Document.OriginalText
        if ($Document.IsFileBacked) {
            $Path = $Document.Path
        }
    }

    if ($Document.Edits.Count -gt 0) {
        Write-Error "The provided AstDocument contains edits and cannot be used."
    }

    $AcceptedCorrections = [List[NitpickCorrection]]::new()
    $SkippedCorrections = [List[object]]::new()
    $SelectedCorrections = [List[NitpickCorrection]]::new()
    $Conflicts = [List[object]]::new()
    $FinalFindings = [List[object]]::new()

    # MARK: CORRECTION SELECTION
    # A correction is one whole fix; its edits apply all-or-nothing. Only Safe
    # corrections are selected, at most one per finding: automatic selection
    # never chooses between alternatives.
    foreach ($SourceFinding in $Finding) {
        $FindingCorrections = @($SourceFinding.Corrections | Where-Object { $null -ne $_ })
        if ($FindingCorrections.Count -eq 0) {
            continue
        }

        $SafeCorrections = @($FindingCorrections | Where-Object { $_.Applicability -eq 'Safe' })
        if ($SafeCorrections.Count -gt 1) {
            $AmbiguousReason = "The finding proposes $($SafeCorrections.Count) Safe corrections; " +
                'automatic selection never chooses between alternatives.'
            foreach ($Correction in $FindingCorrections) {
                $SkippedCorrections.Add([pscustomobject]@{
                    Correction = $Correction
                    Reason = $AmbiguousReason
                })
            }
            continue
        }

        foreach ($Correction in $FindingCorrections) {
            $RejectionReason = if ($Correction.Applicability -ne 'Safe') {
                "Applicability '$($Correction.Applicability)' is not selected."
            } elseif ($Correction.TextEdits.Count -eq 0) {
                'Correction does not contain an AstEditor text edit.'
            }

            if ($RejectionReason) {
                $SkippedCorrections.Add([pscustomobject]@{
                    Correction = $Correction
                    Reason = $RejectionReason
                })
                continue
            }

            $SelectedCorrections.Add($Correction)
        }
    }

    # MARK: ATOMIC QUEUEING
    # AstEditor exclusively validates source ranges, stale text, and conflicts.
    if ($SelectedCorrections.Count -gt 0) {
        try {
            $null = Add-AstTextEdit `
                -Document $Document `
                -TextEdit @($SelectedCorrections.TextEdits)

            foreach ($Correction in $SelectedCorrections) {
                $AcceptedCorrections.Add($Correction)
            }
        } catch {
            $FailureKind = $_.Exception.Data['FailureKind']
            if ($FailureKind -eq 'Conflict') {
                $ExistingEdit = $_.Exception.Data['ExistingEdit']
                $IncomingEdit = $_.Exception.Data['IncomingEdit']

                # Conflict data carries edit field snapshots, so owners are
                # recovered by matching fields against each correction's edits.
                $FindOwner = {
                    param($ConflictEdit, $Exclude)
                    foreach ($Candidate in $SelectedCorrections) {
                        if ($Exclude -and [object]::ReferenceEquals($Candidate, $Exclude)) {
                            continue
                        }
                        foreach ($OwnedEdit in $Candidate.TextEdits) {
                            if ($OwnedEdit.StartOffset -eq $ConflictEdit.StartOffset -and
                                $OwnedEdit.EndOffset -eq $ConflictEdit.EndOffset -and
                                $OwnedEdit.Reason -ceq $ConflictEdit.Reason -and
                                $OwnedEdit.ReplacementText -ceq $ConflictEdit.ReplacementText
                            ) {
                                return $Candidate
                            }
                        }
                    }
                }

                $ExistingCorrection = & $FindOwner $ExistingEdit $null
                $IncomingCorrection = & $FindOwner $IncomingEdit $ExistingCorrection

                # Two edits of the same correction can also conflict; report the
                # single owner rather than hiding the rule-authoring error.
                if (-not $IncomingCorrection) {
                    $IncomingCorrection = $ExistingCorrection
                }

                $Conflicts.Add([pscustomobject]@{
                    ExistingCorrection = $ExistingCorrection
                    IncomingCorrection = $IncomingCorrection
                    Reason = (
                        "{0} Existing rule '{1}', correction '{2}'; incoming rule '{3}', correction '{4}'." -f
                            $_.Exception.Message,
                            (Get-NitpickRuleLabel -InputObject $ExistingCorrection),
                            $ExistingCorrection.Description,
                            (Get-NitpickRuleLabel -InputObject $IncomingCorrection),
                            $IncomingCorrection.Description
                    )
                })
            }

            $RejectionReason = if ($FailureKind -eq 'Conflict') {
                'AstEditor rejected the target because the selected edits conflict.'
            } elseif ($FailureKind -eq 'ExpectedTextMismatch') {
                'AstEditor rejected the target because an edit is stale.'
            } else {
                "AstEditor rejected the target batch: $($_.Exception.Message)"
            }

            foreach ($Correction in $SelectedCorrections) {
                $SkippedCorrections.Add([pscustomobject]@{
                    Correction = $Correction
                    Reason = $RejectionReason
                })
            }
        }
    }

    # MARK: RENDERING
    # Render and parse the selected batch without changing the source file.
    $Resolution = Resolve-AstDocument -Document $Document -PassThruText
    $CandidateText = $Resolution.RenderedText

    if ($AcceptedCorrections.Count -gt 0 -and $Resolution.ParseErrorCount -gt 0) {
        foreach ($Correction in $AcceptedCorrections) {
            $SkippedCorrections.Add([pscustomobject]@{
                Correction = $Correction
                Reason = 'The rendered correction batch contains parse errors.'
            })
        }

        $AcceptedCorrections.Clear()
    }

    # MARK: FINAL REANALYSIS
    # Rerun only the caller-selected rules, and only after rendered text passes validation.
    $WasReanalyzed = $false
    if ($Rule.Count -gt 0 -and $Resolution.ParseErrorCount -eq 0) {
        $RenderedAst = if ($Path) {
            $Tokens = $null
            $ParseErrors = $null
            [Parser]::ParseInput(
                $CandidateText,
                $Path,
                [ref] $Tokens,
                [ref] $ParseErrors
            )
        } else {
            (New-AstDocument -InputObject $CandidateText).Ast
        }

        foreach ($SelectedRule in $Rule) {
            foreach ($FinalFinding in $SelectedRule.Invoke($RenderedAst)) {
                $FinalFindings.Add($FinalFinding)
            }
        }

        $WasReanalyzed = $true
    }

    return [NitpickCorrectionProposal]@{
        Path = if ($Path) { $Path } else { '<ScriptBlock>' }
        Document = $Document
        OriginalFingerprint = $Document.OriginalFingerprint
        OriginalText = $Script
        OriginalFindings = @($Finding)
        WasReanalyzed = $WasReanalyzed

        Status = if ($Resolution.ParseErrorCount -gt 0) {
            'FailedValidation'
        } elseif ($SelectedCorrections.Count -gt 0 -and $AcceptedCorrections.Count -eq 0) {
            'Rejected'
        } elseif ($AcceptedCorrections.Count -eq 0) {
            'NoChanges'
        } else {
            'Ready'
        }

        CandidateFindings = $FinalFindings.ToArray()
        AcceptedCorrections = $AcceptedCorrections.ToArray()
        SkippedCorrections = $SkippedCorrections.ToArray()
        Conflicts = $Conflicts.ToArray()
        ParseErrors = @($Resolution.ParseErrors)
        CandidateText = $CandidateText
        Diff = Show-AstDiff -Document $Document -Label Position -Annotate
    }
}
