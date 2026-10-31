<#
.SYNOPSIS
    Counts corrections as users see them, treating each change set as one correction.

.DESCRIPTION
    Rules can split one logical fix into several edits that share a ChangeSetId and are
    applied all-or-nothing. This command counts each distinct ChangeSetId once and each
    correction without a ChangeSetId individually. ChangeSetId comparison is
    case-insensitive.

    Used for text output only. Object output keeps every individual edit in
    Proposal.AcceptedCorrections and Application.CommittedCorrections.

.PARAMETER Corrections
    The corrections to count, such as Proposal.AcceptedCorrections or
    Application.CommittedCorrections. An empty collection returns zero.

.EXAMPLE
    Get-NitpickCorrectionCount -Corrections $Proposal.AcceptedCorrections

    Returns 1 for the two edits of a UseIsNotOperator fix, because they share a ChangeSetId.
#>
function Get-NitpickCorrectionCount {
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Corrections
    )

    $ChangeSetIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $Count = 0

    foreach ($Item in $Corrections) {
        if ([string]::IsNullOrEmpty($Item.ChangeSetId)) {
            $Count++
            continue
        }

        if ($ChangeSetIds.Add($Item.ChangeSetId)) {
            $Count++
        }
    }

    return $Count
}
