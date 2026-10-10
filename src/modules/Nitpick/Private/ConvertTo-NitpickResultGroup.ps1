
<#
.SYNOPSIS
    Merges a partial hashtable of values into a complete grouped result object.

.DESCRIPTION
    Builds a Nitpick.CorrectionResult subgroup (Findings or Corrections) from a
    caller-supplied hashtable, defaulting every unspecified property to an empty
    array. Keeps New-NitpickCorrectionResult callers free to supply only the
    properties relevant to their stage of the pipeline.

.PARAMETER PropertyName
    The ordered property names that make up the result group.

.PARAMETER Value
    A hashtable of property overrides. Keys not present default to an empty array.

.EXAMPLE
    ConvertTo-NitpickResultGroup -PropertyName 'Accepted', 'Fixed' -Value @{ Accepted = $Corrections }

    Creates a group object with populated Accepted and empty Fixed.
#>
function ConvertTo-NitpickResultGroup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [string[]] $PropertyName,

        [hashtable] $Value = @{}
    )

    $Group = [ordered]@{}
    foreach ($Name in $PropertyName) {
        # Wrapping the whole if/else in @() prevents PowerShell from collapsing
        # an empty-array branch to $null on assignment.
        $Group[$Name] = @(if ($Value.Contains($Name)) { $Value[$Name] } else { @() })
    }
    [pscustomobject] $Group
}
