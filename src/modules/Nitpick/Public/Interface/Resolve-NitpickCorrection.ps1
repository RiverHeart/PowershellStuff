<#
.SYNOPSIS
    Previews native Nitpick corrections against one source snapshot.

.DESCRIPTION
    Evaluates safe, offset-based corrections against immutable in-memory source and
    returns rendered text and parse diagnostics without writing files. Corrections
    sharing a ChangeSetId are accepted or skipped together. A correction without a
    ChangeSetId forms its own independent change set.

.PARAMETER Script
    The exact source snapshot from which the correction offsets were calculated.

.PARAMETER Finding
    Native Nitpick findings containing corrections produced from the source snapshot.

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
    $Result.Conflicts
    $Result.RenderedText -eq $Source

    Inspects conflicts when independent change sets overlap. Under the target-level conflict
    policy, an overlap rejects the complete preview batch and leaves RenderedText unchanged.
#>
function Resolve-NitpickCorrection {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Script,

        [Parameter(Mandatory)]
        [NitpickFinding[]] $Finding
    )

    $Document = New-AstDocument -InputObject $Script
    $AcceptedCorrections = [System.Collections.Generic.List[NitpickCorrection]]::new()
    $SkippedCorrections = [System.Collections.Generic.List[object]]::new()
    $ChangeSets = [ordered]@{}
    $StandaloneCorrectionId = 0

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

    foreach ($ChangeSetKey in $ChangeSets.Keys) {
        $ChangeSet = $ChangeSets[$ChangeSetKey]
        $RejectionReason = $null
        foreach ($Correction in $ChangeSet) {
            if ($Correction.Applicability -ne 'Safe') {
                $RejectionReason = "Applicability '$($Correction.Applicability)' is not selected."
                break
            }
            if (-not $Correction.HasOffsets) {
                $RejectionReason = 'Correction does not contain snapshot offsets.'
                break
            }
            if ($Correction.StartOffset -lt 0 -or
                $Correction.EndOffset -lt $Correction.StartOffset -or
                $Correction.EndOffset -gt $Script.Length
            ) {
                $RejectionReason = 'Correction offsets are outside the source snapshot.'
                break
            }
            $ActualText = $Script.Substring(
                $Correction.StartOffset,
                $Correction.EndOffset - $Correction.StartOffset
            )
            if ($ActualText -cne $Correction.ExpectedText) {
                $RejectionReason = 'Expected source text does not match the source snapshot.'
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
            $null = Add-AstTextEdit `
                -Document $Document `
                -StartOffset $Correction.StartOffset `
                -EndOffset $Correction.EndOffset `
                -ReplacementText $Correction.ReplacementText `
                -Reason $Correction.Description `
                -ExpectedText $Correction.ExpectedText
            $AcceptedCorrections.Add($Correction)
        }
    }

    $Resolution = Resolve-AstDocument -Document $Document -PassThruText

    return [pscustomobject]@{
        PSTypeName = 'Nitpick.CorrectionPreviewResult'
        Path = '<ScriptBlock>'
        AcceptedCorrections = @($AcceptedCorrections)
        SkippedCorrections = @($SkippedCorrections)
        Conflicts = @()
        ParseErrors = @($Resolution.ParseErrors)
        RenderedText = $Resolution.RenderedText
        WasWritten = $false
    }
}
