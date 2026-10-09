<#
.SYNOPSIS
    Creates a Nitpick correction result with a consistent property schema.

.DESCRIPTION
    Creates the result shared by correction previews, applications, and read failures.
    Collections default to empty arrays, write and reanalysis flags default to false,
    and optional diagnostic values default to null. This helper only constructs the
    result; it does not resolve corrections, analyze source, or write files.

.PARAMETER WriteStatus
    The transaction status. Defaults to Preview; callers supply the actual outcome.

.EXAMPLE
    New-NitpickCorrectionPreviewResult -Path $Path -WriteStatus FailedRead -ErrorRecord $_

    Creates a failed-read result with the same properties as a correction preview.
#>
function New-NitpickCorrectionPreviewResult {
    [CmdletBinding()]
    [OutputType('Nitpick.CorrectionPreviewResult')]
    param (
        [string] $Path = '<ScriptBlock>',

        [string] $WriteStatus = 'Preview',

        [AllowNull()]
        [string] $OriginalFingerprint,

        [psobject] $Document,

        [psobject] $WriteResult,

        [bool] $WasWritten = $false,

        [bool] $WasReanalyzed = $false,

        [object[]] $OriginalFindings = @(),

        [object[]] $FinalFindings = @(),

        [object[]] $CandidateFindings = @(),

        [object[]] $RemainingFindings = @(),

        [object[]] $AcceptedCorrections = @(),

        [object[]] $FixedCorrections = @(),

        [object[]] $FixedFindings = @(),

        [object[]] $SkippedFindings = @(),

        [object[]] $ConflictedFindings = @(),

        [object[]] $FailedValidationFindings = @(),

        [object[]] $SkippedCorrections = @(),

        [object[]] $Conflicts = @(),

        [object[]] $ParseErrors = @(),

        [AllowNull()]
        [AllowEmptyString()]
        [string] $CandidateText,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $RenderedText,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $Diff,

        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    [pscustomobject]@{
        PSTypeName = 'Nitpick.CorrectionPreviewResult'
        Path = $Path
        WriteStatus = $WriteStatus
        OriginalFingerprint = if ($OriginalFingerprint) { $OriginalFingerprint } else { $null }
        Document = $Document
        WriteResult = $WriteResult
        WasWritten = $WasWritten
        WasReanalyzed = $WasReanalyzed
        OriginalFindings = $OriginalFindings
        FinalFindings = $FinalFindings
        CandidateFindings = $CandidateFindings
        RemainingFindings = $RemainingFindings
        AcceptedCorrections = $AcceptedCorrections
        FixedCorrections = $FixedCorrections
        FixedFindings = $FixedFindings
        SkippedFindings = $SkippedFindings
        ConflictedFindings = $ConflictedFindings
        FailedValidationFindings = $FailedValidationFindings
        SkippedCorrections = $SkippedCorrections
        Conflicts = $Conflicts
        ParseErrors = $ParseErrors
        CandidateText = $PSBoundParameters['CandidateText']
        RenderedText = $PSBoundParameters['RenderedText']
        Diff = $PSBoundParameters['Diff']
        ErrorRecord = $ErrorRecord
    }
}
