using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation

<#
.SYNOPSIS
    Validates supplied settings against a rule's schema and applies defaults.

.DESCRIPTION
    Returns a new hashtable containing every setting declared by the schema. A
    supplied value replaces the default after it passes type and range checks.
    Setting names match case-insensitively and are returned in the schema's
    casing, so a rule can always read $Context.RuleSettings.MaximumLength.

    Unknown setting names are errors rather than being ignored, so a typo in a
    configuration file fails instead of silently running with the default.

    NitpickRule calls this before every invocation to build the rule's
    Context.RuleSettings. ConvertTo-NitpickRuleSettingsMap calls it earlier, when
    configuration is loaded, so invalid values fail before any target is read.

.PARAMETER Schema
    A normalized schema from ConvertTo-NitpickRuleSettingsSchema.

.PARAMETER Values
    Supplied settings keyed by setting name. Must be a dictionary; use an empty
    dictionary to request only defaults.

.PARAMETER RuleId
    The qualified rule ID used in error messages.

.PARAMETER Source
    Optional description of where the values came from, such as
    "configuration '.\nitpick.psd1'", used in error messages.

.EXAMPLE
    $Schema = ConvertTo-NitpickRuleSettingsSchema -RuleId 'Local/Example' -Settings @{
        MaximumLength = @{ Type = 'Integer'; Default = 120; Minimum = 1 }
    }
    ConvertTo-NitpickEffectiveRuleSettings -Schema $Schema -Values @{} -RuleId 'Local/Example'

    Returns @{ MaximumLength = 120 }: omitted settings receive their defaults.

.EXAMPLE
    $Schema = ConvertTo-NitpickRuleSettingsSchema -RuleId 'Local/Example' -Settings @{
        MaximumLength = @{ Type = 'Integer'; Default = 120; Minimum = 1 }
    }
    ConvertTo-NitpickEffectiveRuleSettings -Schema $Schema -Values @{ maximumlength = 0 } -RuleId 'Local/Example'

    Throws "Invalid settings for Nitpick rule 'Local/Example': setting
    'MaximumLength' must be at least 1; actual value is 0."

.NOTES
    Private helper; examples run within Nitpick's module scope. Errors use the
    NitpickInvalidRuleSettings error ID.
#>
function ConvertTo-NitpickEffectiveRuleSettings {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [IDictionary] $Schema,

        [AllowNull()]
        [object] $Values,

        [Parameter(Mandatory)]
        [string] $RuleId,

        [string] $Source
    )

    try {
        if ($Values -isnot [IDictionary]) {
            throw [ArgumentException]::new('settings must be a dictionary keyed by setting name.')
        }

        $Effective = @{}
        foreach ($Name in $Schema.Keys) {
            $Effective[$Name] = $Schema[$Name].Default
        }

        $SeenNames = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($Name in $Values.psbase.Keys) {
            if ($Name -isnot [string]) {
                throw [ArgumentException]::new("setting name '$Name' must be a string.")
            }

            if (-not $SeenNames.Add($Name)) {
                throw [ArgumentException]::new(
                    "setting '$Name' is supplied more than once with different casing."
                )
            }

            $CanonicalName = @($Schema.Keys | Where-Object { $_ -ieq $Name } | Select-Object -First 1)
            if ($CanonicalName.Count -eq 0) {
                $Known = if ($Schema.Count -gt 0) {
                    'known settings: ' + (@($Schema.Keys | Sort-Object) -join ', ')
                } else {
                    'this rule declares no settings'
                }

                throw [ArgumentException]::new("unknown setting '$Name' ($Known).")
            }

            $CanonicalName = $CanonicalName[0]
            $Value = ConvertTo-NitpickInt32SettingValue `
                -Value $Values[$Name] `
                -Name "setting '$CanonicalName'"

            $Definition = $Schema[$CanonicalName]

            if ($Definition.ContainsKey('Minimum') -and $Value -lt $Definition.Minimum) {
                throw [ArgumentException]::new(
                    "setting '$CanonicalName' must be at least $($Definition.Minimum); actual value is $Value."
                )
            }

            if ($Definition.ContainsKey('Maximum') -and $Value -gt $Definition.Maximum) {
                throw [ArgumentException]::new(
                    "setting '$CanonicalName' must be at most $($Definition.Maximum); actual value is $Value."
                )
            }
            $Effective[$CanonicalName] = $Value
        }

        return $Effective
    } catch {
        $Location = if ($Source) { " in $Source" } else { '' }
        $Exception = [ArgumentException]::new(
            "Invalid settings for Nitpick rule '$RuleId'$($Location): $($_.Exception.Message)",
            $_.Exception
        )
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $Exception,
            'NitpickInvalidRuleSettings',
            [ErrorCategory]::InvalidData,
            $RuleId
        ))
    }
}
