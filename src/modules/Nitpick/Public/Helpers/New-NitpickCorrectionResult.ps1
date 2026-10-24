<#
.SYNOPSIS
    Creates a Nitpick correction result with a consistent property schema.

.DESCRIPTION
    Creates the result shared by correction previews, applications, and read failures.
    Findings and Corrections are grouped sub-objects so similarly named outcomes (for
    example Findings.Skipped versus Corrections.Skipped) stay unambiguous. Omitted
    group properties default to empty arrays, write and reanalysis flags default to
    false, and optional diagnostic values default to null. This helper only constructs
    the result; it does not resolve corrections, analyze source, or write files.

.PARAMETER WriteStatus
    The transaction status. Defaults to Preview; callers supply the actual outcome.

.PARAMETER Findings
    A hashtable overriding any of Original, Candidate, Final, Remaining, Fixed,
    Skipped, Conflicted, or FailedValidation. Omitted keys default to an empty array.

.PARAMETER Corrections
    A hashtable overriding any of Accepted, Fixed, Skipped, or Conflicts. Omitted
    keys default to an empty array.

.EXAMPLE
    New-NitpickCorrectionResult -Path $Path -WriteStatus FailedRead -ErrorRecord $_

    Creates a failed-read result with the same schema as a correction preview.

.EXAMPLE
    New-NitpickCorrectionResult -Findings @{ Original = $Finding; Final = $Finding }

    Creates a result with original and final findings populated and every other
    Findings and Corrections property defaulted to an empty array.
#>
function New-NitpickCorrectionResult {
    [CmdletBinding()]
    [OutputType('Nitpick.CorrectionResult')]
    param (
        [string] $Path = '<ScriptBlock>',

        [string] $WriteStatus = 'Preview',

        [AllowNull()]
        [string] $OriginalFingerprint,

        [psobject] $Document,

        [psobject] $WriteResult,

        [bool] $WasWritten = $false,

        [bool] $WasReanalyzed = $false,

        [hashtable] $Findings = @{},

        [hashtable] $Corrections = @{},

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
        PSTypeName = 'Nitpick.CorrectionResult'
        Path = $Path
        WriteStatus = $WriteStatus
        OriginalFingerprint = if ($OriginalFingerprint) { $OriginalFingerprint } else { $null }
        Document = $Document
        WriteResult = $WriteResult
        WasWritten = $WasWritten
        WasReanalyzed = $WasReanalyzed
        Findings = ConvertTo-NitpickResultGroup `
            -PropertyName 'Original', 'Candidate', 'Final', 'Remaining', 'Fixed', 'Skipped', 'Conflicted', 'FailedValidation' `
            -Value $Findings
        Corrections = ConvertTo-NitpickResultGroup `
            -PropertyName 'Accepted', 'Fixed', 'Skipped', 'Conflicts' `
            -Value $Corrections
        ParseErrors = $ParseErrors
        CandidateText = $PSBoundParameters['CandidateText']
        RenderedText = $PSBoundParameters['RenderedText']
        Diff = $PSBoundParameters['Diff']
        ErrorRecord = $ErrorRecord
    }
}
