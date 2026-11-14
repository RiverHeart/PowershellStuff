using namespace System
using namespace System.Collections
using namespace System.Management.Automation

<#
.SYNOPSIS
    Validates a settings map keyed by qualified rule ID and returns a private copy.

.DESCRIPTION
    A rule-settings map looks like the Rules section of a nitpick.psd1 file:

        @{ 'Nitpick/AvoidLongLines' = @{ MaximumLength = 100 } }

    This is the one place that checks a map's shape. Keys must be distinct
    (ignoring case) and valid Namespace/Name rule IDs, and each value must be a
    settings dictionary. The result is a plain-data copy, so later changes to the
    caller's map cannot affect validated settings.

    When Rule is supplied, every configured ID must also match one of those rule
    descriptors, and its values are checked against that descriptor's schema.
    Callers that have already done this, such as Start-Nitpicking after loading
    configuration, can trust the map without validating it again.

.PARAMETER RuleSettings
    The map to validate. Null returns an empty map.

.PARAMETER Rule
    Optional rule descriptors that the map's IDs and values are checked against.
    When several descriptors share an ID, they must wrap the same callable; put
    the descriptor whose schema should win first.

.PARAMETER Source
    Describes where the map came from in error messages, such as
    "configuration '.\nitpick.psd1'".

.EXAMPLE
    ConvertTo-NitpickRuleSettingsMap -RuleSettings @{
        'Nitpick/AvoidLongLines' = @{ MaximumLength = 100 }
    }

    Returns a copy of the map after checking only its shape.

.EXAMPLE
    $Rule = New-Nitpick -Callable Measure-AvoidLongLines
    ConvertTo-NitpickRuleSettingsMap -Rule $Rule -RuleSettings @{
        'Nitpick/AvoidLongLines' = @{ MaximumLenght = 100 }
    }

    Throws "Invalid settings for Nitpick rule 'Nitpick/AvoidLongLines' in
    RuleSettings: unknown setting 'MaximumLenght' (known settings: MaximumLength)."

.NOTES
    Private helper; examples run within Nitpick's module scope. Errors use the
    NitpickInvalidRuleSettings error ID.
#>
function ConvertTo-NitpickRuleSettingsMap {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowNull()]
        [object] $RuleSettings,

        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]] $Rule,

        [string] $Source = 'RuleSettings'
    )

    try {
        if ($null -eq $RuleSettings) { return @{} }
        if ($RuleSettings -isnot [IDictionary]) {
            throw [ArgumentException]::new('the map must be a dictionary keyed by qualified rule ID.')
        }

        # The copy rejects non-string and case-duplicate keys.
        $Map = Copy-NitpickPlainData -Value $RuleSettings -Path $Source
        foreach ($RuleId in $Map.Keys) {
            Assert-NitpickRuleId -Value $RuleId
            if ($Map[$RuleId] -isnot [IDictionary]) {
                throw [ArgumentException]::new(
                    "settings for '$RuleId' must be a dictionary keyed by setting name."
                )
            }
        }

        if (-not $PSBoundParameters.ContainsKey('Rule')) { return $Map }

        foreach ($RuleId in $Map.Keys) {
            $Matching = @($Rule | Where-Object { $null -ne $_ -and $_.Id -ieq $RuleId })
            if ($Matching.Count -eq 0) {
                throw [ArgumentException]::new(
                    "unknown Nitpick rule ID '$RuleId'; no rule available to this call has that ID."
                )
            }

            foreach ($Candidate in $Matching | Select-Object -Skip 1) {
                $IsSameCallable = Test-NitpickCallableIdentity `
                    -Left $Matching[0].Callable `
                    -Right $Candidate.Callable

                if (-not $IsSameCallable) {
                    throw [ArgumentException]::new(
                        "different callables share the rule ID '$RuleId', so its settings schema is " +
                        'ambiguous. Register one descriptor or remove the conflict.'
                    )
                }
            }

            $null = ConvertTo-NitpickEffectiveRuleSettings `
                -Schema $Matching[0].Settings `
                -Values $Map[$RuleId] `
                -RuleId $Matching[0].Id `
                -Source $Source `
                -ErrorAction Stop
        }

        return $Map
    } catch {
        if ($_.FullyQualifiedErrorId -like 'NitpickInvalidRuleSettings,*') {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        $Exception = [ArgumentException]::new(
            "Invalid rule settings in $($Source): $($_.Exception.Message)",
            $_.Exception
        )

        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $Exception,
            'NitpickInvalidRuleSettings',
            [ErrorCategory]::InvalidData,
            $Source
        ))
    }
}
