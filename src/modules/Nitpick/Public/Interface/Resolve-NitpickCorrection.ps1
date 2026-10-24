<#
.SYNOPSIS
    Previews native Nitpick corrections against one source snapshot.

.DESCRIPTION
    Selects safe corrections and delegates atomic source validation and queueing to
    AstEditor. Corrections sharing a ChangeSetId are selected or skipped together. A
    correction without a ChangeSetId forms its own independent change set. IDs are
    target-wide; producers should include their rule identity and occurrence in IDs
    unless they intentionally coordinate across findings or rules. If the
    selected batch is stale or conflicting, AstEditor rejects it without queueing any
    member. If a candidate introduces parse errors, RenderedText remains the original
    source and CandidateText contains the rejected output for diagnostics. The result
    includes the edit diff and final findings when rules are supplied.

.PARAMETER Script
    The exact source snapshot from which the correction offsets were calculated.

.PARAMETER Document
    The AstEditor document analyzed by Nitpick. Its snapshot and queued transaction
    are retained in the result so preview and file application use the same edits.

.PARAMETER Finding
    Native Nitpick findings containing corrections produced from the source snapshot.

.PARAMETER Rule
    Selected Nitpick rules to rerun against valid rendered text. When omitted, the
    correction preview is returned without final reanalysis.

.PARAMETER Path
    Optional source path used to retain file identity during final rule analysis.

.EXAMPLE
    $Result = Resolve-NitpickCorrection -Script $Source -Finding $Finding
    $Result.RenderedText

    Previews all independent safe corrections attached to the findings. Every correction
    without a ChangeSetId is evaluated independently, and all accepted corrections are
    rendered against the original source snapshot in one pass.

.EXAMPLE
    $Corrections = @(
        New-NitpickCorrection `
            -ViolationExtent $FirstExtent `
            -ReplacementText '$First = 2' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the first assignment.' `
            -ChangeSetId 'CoupledAssignments'

        New-NitpickCorrection `
            -ViolationExtent $SecondExtent `
            -ReplacementText '$Second = 3' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the second assignment.' `
            -ChangeSetId 'CoupledAssignments'
    )
    $Result = Resolve-NitpickCorrection -Script $Source -Finding $Finding

    When $Finding contains $Corrections, both corrections are accepted or skipped together.
    For example, stale ExpectedText on either correction skips the complete change set.

.EXAMPLE
    $Result = Resolve-NitpickCorrection -Script $Source -Finding $Finding
    $Result.Corrections.Conflicts
    $Result.RenderedText -eq $Source

    Inspects conflicts when independent change sets overlap. Under the target-level conflict
    policy, an overlap rejects the complete preview batch and leaves RenderedText unchanged.

.EXAMPLE
    $Result = Resolve-NitpickCorrection `
        -Script $Source `
        -Finding $Finding `
        -Rule $SelectedRules
    $Result.Findings.Final

    Passes the rules that produced the original findings when the preview must verify that
    corrected findings disappear and report findings that remain after rendering. Omit Rule
    when only correction selection, validation, and rendered text are needed.
#>
function Resolve-NitpickCorrection {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Script')]
        [AllowEmptyString()]
        [string] $Script,

        [Parameter(Mandatory, ParameterSetName = 'Document')]
        [ValidateScript({ $_.GetType().Name -eq 'AstDocument' -and $_.Edits.Count -eq 0 })]
        [psobject] $Document,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [NitpickFinding[]] $Finding,

        [NitpickRule[]] $Rule,

        [AllowNull()]
        [string] $Path
    )

    if ($PSCmdlet.ParameterSetName -eq 'Script') {
        $Document = New-AstDocument -InputObject $Script
    } else {
        $Script = $Document.OriginalText
        if ($Document.IsFileBacked) {
            $Path = $Document.Path
        }
    }
    $AcceptedCorrections = [System.Collections.Generic.List[NitpickCorrection]]::new()
    $SkippedCorrections = [System.Collections.Generic.List[object]]::new()
    $SelectedCorrections = [System.Collections.Generic.List[NitpickCorrection]]::new()
    $Conflicts = [System.Collections.Generic.List[object]]::new()
    $FinalFindings = [System.Collections.Generic.List[object]]::new()
    $ChangeSets = [ordered]@{}
    $StandaloneCorrectionId = 0

    # MARK: CHANGE SET GROUPING
    # Build all-or-nothing change sets while keeping ungrouped corrections independent.
    foreach ($Correction in $Finding.Corrections) {
        $ChangeSetKey = if ($Correction.ChangeSetId) {
            "ChangeSet:$($Correction.ChangeSetId)"
        } else {
            "Correction:$StandaloneCorrectionId"
        }
        if (-not $ChangeSets.Contains($ChangeSetKey)) {
            $ChangeSets[$ChangeSetKey] = [System.Collections.Generic.List[NitpickCorrection]]::new()
        }
        $ChangeSets[$ChangeSetKey].Add($Correction)
        $StandaloneCorrectionId++
    }

    # MARK: CHANGE SET SELECTION
    # Select only complete change sets that satisfy Nitpick correction policy.
    foreach ($ChangeSetKey in $ChangeSets.Keys) {
        $ChangeSet = $ChangeSets[$ChangeSetKey]
        $RejectionReason = $null
        foreach ($Correction in $ChangeSet) {
            if ($Correction.Applicability -ne 'Safe') {
                $RejectionReason = "Applicability '$($Correction.Applicability)' is not selected."
                break
            }
            if (-not $Correction.TextEdit) {
                $RejectionReason = 'Correction does not contain an AstEditor text edit.'
                break
            }
        }

        if ($RejectionReason) {
            foreach ($Correction in $ChangeSet) {
                $SkippedCorrections.Add([pscustomobject]@{
                    Correction = $Correction
                    Reason = $RejectionReason
                })
            }
            continue
        }

        foreach ($Correction in $ChangeSet) {
            $SelectedCorrections.Add($Correction)
        }
    }

    # MARK: ATOMIC QUEUEING
    # AstEditor exclusively validates source ranges, stale text, and conflicts.
    if ($SelectedCorrections.Count -gt 0) {
        try {
            $null = Add-AstTextEdit `
                -Document $Document `
                -TextEdit @($SelectedCorrections.TextEdit)

            foreach ($Correction in $SelectedCorrections) {
                $AcceptedCorrections.Add($Correction)
            }
        } catch {
            $FailureKind = $_.Exception.Data['FailureKind']
            if ($FailureKind -eq 'Conflict') {
                $ExistingEdit = $_.Exception.Data['ExistingEdit']
                $IncomingEdit = $_.Exception.Data['IncomingEdit']
                $ExistingCorrection = $SelectedCorrections |
                    Where-Object {
                        $_.TextEdit.StartOffset -eq $ExistingEdit.StartOffset -and
                            $_.TextEdit.EndOffset -eq $ExistingEdit.EndOffset -and
                            $_.TextEdit.Reason -ceq $ExistingEdit.Reason -and
                            $_.TextEdit.ReplacementText -ceq $ExistingEdit.ReplacementText
                    } |
                    Select-Object -First 1
                $IncomingCorrection = $SelectedCorrections |
                    Where-Object {
                        $_.TextEdit.StartOffset -eq $IncomingEdit.StartOffset -and
                            $_.TextEdit.EndOffset -eq $IncomingEdit.EndOffset -and
                            $_.TextEdit.Reason -ceq $IncomingEdit.Reason -and
                            $_.TextEdit.ReplacementText -ceq $IncomingEdit.ReplacementText -and
                            -not [object]::ReferenceEquals($_, $ExistingCorrection)
                    } |
                    Select-Object -First 1
                $Conflicts.Add([pscustomobject]@{
                    ExistingCorrection = $ExistingCorrection
                    IncomingCorrection = $IncomingCorrection
                    Reason = (
                        "{0} Existing rule '{1}', change set '{2}'; incoming rule '{3}', change set '{4}'." -f
                            $_.Exception.Message,
                            $ExistingCorrection.RuleName,
                            $ExistingCorrection.ChangeSetId,
                            $IncomingCorrection.RuleName,
                            $IncomingCorrection.ChangeSetId
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
    $RenderedText = $CandidateText

    if ($AcceptedCorrections.Count -gt 0 -and $Resolution.ParseErrorCount -gt 0) {
        foreach ($Correction in $AcceptedCorrections) {
            $SkippedCorrections.Add([pscustomobject]@{
                Correction = $Correction
                Reason = 'The rendered correction batch contains parse errors.'
            })
        }
        $AcceptedCorrections.Clear()
        $RenderedText = $Script
    }

    # MARK: FINAL REANALYSIS
    # Rerun only the caller-selected rules, and only after rendered text passes validation.
    $WasReanalyzed = $false
    if ($Rule.Count -gt 0 -and $Resolution.ParseErrorCount -eq 0) {
        $RenderedAst = if ($Path) {
            $Tokens = $null
            $ParseErrors = $null
            [Parser]::ParseInput(
                $RenderedText,
                $Path,
                [ref] $Tokens,
                [ref] $ParseErrors
            )
        } else {
            (New-AstDocument -InputObject $RenderedText).Ast
        }
        foreach ($SelectedRule in $Rule) {
            foreach ($FinalFinding in $SelectedRule.Invoke($RenderedAst)) {
                $FinalFindings.Add($FinalFinding)
            }
        }
        $WasReanalyzed = $true
    }

    $ResultParameters = @{
        Path = if ($Path) { $Path } else { '<ScriptBlock>' }
        Document = $Document
        OriginalFingerprint = $Document.OriginalFingerprint
        WasReanalyzed = $WasReanalyzed
        WriteStatus = if ($Resolution.ParseErrorCount -gt 0) {
            'FailedValidation'
        } elseif ($SelectedCorrections.Count -gt 0 -and $AcceptedCorrections.Count -eq 0) {
            'Rejected'
        } elseif ($AcceptedCorrections.Count -eq 0) {
            'NoChanges'
        } else {
            'Preview'
        }
        Findings = @{
            Original = $Finding
            Final = $FinalFindings.ToArray()
            Candidate = $FinalFindings.ToArray()
            Remaining = @(if ($WasReanalyzed) { $FinalFindings.ToArray() } else { $Finding })
        }
        Corrections = @{
            Accepted = $AcceptedCorrections.ToArray()
            Skipped = $SkippedCorrections.ToArray()
            Conflicts = $Conflicts.ToArray()
        }
        ParseErrors = $Resolution.ParseErrors
        CandidateText = $CandidateText
        RenderedText = $RenderedText
        Diff = Show-AstDiff -Document $Document
    }
    New-NitpickCorrectionResult @ResultParameters
}
