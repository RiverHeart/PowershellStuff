using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation

<#
.SYNOPSIS
    Validates a rule's declared settings and returns a normalized schema.

.DESCRIPTION
    A rule declares its settings through Details metadata or the New-Nitpick and
    Register-Nitpick -Settings parameter. Each setting must declare
    Type = 'Integer' and a Default, and may declare Minimum and Maximum. The
    Default must fall within the declared bounds.

    The schema belongs to the rule descriptor. NitpickRule runs this conversion
    when a descriptor is constructed, so a malformed declaration fails when the
    rule is created or registered. Without that check, it would fail only when a
    project first configured the setting.

    Normalizing an already normalized schema returns an equivalent schema. This
    lets a registered descriptor be rebuilt from another descriptor without losing
    its settings.

.PARAMETER Settings
    The declared settings dictionary, keyed by setting name. Null declares no
    settings.

.PARAMETER RuleId
    The qualified rule ID used in error messages.

.EXAMPLE
    ConvertTo-NitpickRuleSettingsSchema -RuleId 'Local/Example' -Settings @{
        MaximumLength = @{ Type = 'integer'; Default = [int16] 120; Minimum = 1 }
    }

    Returns @{ MaximumLength = @{ Type = 'Integer'; Default = 120; Minimum = 1 } }
    with canonical Type casing and Int32 values.

.EXAMPLE
    ConvertTo-NitpickRuleSettingsSchema -RuleId 'Local/Example' -Settings @{
        MaximumLength = @{ Type = 'Integer'; Default = 0; Minimum = 1 }
    }

    Throws "Invalid settings schema for Nitpick rule 'Local/Example': setting
    'MaximumLength' Default 0 is below Minimum 1."

.NOTES
    Private helper; examples run within Nitpick's module scope. Values supplied by
    configuration or callers are checked against the result by
    ConvertTo-NitpickEffectiveRuleSettings.
#>
function ConvertTo-NitpickRuleSettingsSchema {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowNull()]
        [object] $Settings,

        [string] $RuleId = '<unknown>'
    )

    try {
        if ($null -eq $Settings) { return @{} }
        if ($Settings -isnot [IDictionary]) {
            throw [ArgumentException]::new('Settings must be a dictionary or null.')
        }

        $Schema = @{}
        $SeenNames = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($Name in $Settings.psbase.Keys) {
            if ($Name -isnot [string] -or $Name -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
                throw [ArgumentException]::new("invalid setting name '$Name'.")
            }

            if (-not $SeenNames.Add($Name)) {
                throw [ArgumentException]::new(
                    "setting '$Name' is declared more than once with different casing."
                )
            }

            $Definition = $Settings[$Name]
            if ($Definition -isnot [IDictionary]) {
                throw [ArgumentException]::new("setting '$Name' must be declared with a dictionary.")
            }

            $SeenDefinitionKeys = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($Key in $Definition.psbase.Keys) {
                if ($Key -isnot [string] -or
                    $Key -notin 'Type', 'Default', 'Minimum', 'Maximum'
                ) {
                    throw [ArgumentException]::new(
                        "setting '$Name' has unsupported schema key '$Key'; " +
                        'use Type, Default, Minimum, or Maximum.'
                    )
                }

                if (-not $SeenDefinitionKeys.Add($Key)) {
                    throw [ArgumentException]::new(
                        "setting '$Name' declares schema key '$Key' more than once with different casing."
                    )
                }
            }

            if (-not $Definition.Contains('Type') -or
                $Definition.Type -isnot [string] -or
                $Definition.Type -ine 'Integer'
            ) {
                throw [ArgumentException]::new("setting '$Name' must declare Type = 'Integer'.")
            }

            if (-not $Definition.Contains('Default')) {
                throw [ArgumentException]::new("setting '$Name' must declare a Default.")
            }

            $Normalized = @{
                Type = 'Integer'
                Default = ConvertTo-NitpickInt32SettingValue `
                    -Value $Definition.Default `
                    -Name "setting '$Name' Default"
            }

            foreach ($Bound in 'Minimum', 'Maximum') {
                if ($Definition.Contains($Bound)) {
                    $Normalized[$Bound] = ConvertTo-NitpickInt32SettingValue `
                        -Value $Definition[$Bound] `
                        -Name "setting '$Name' $Bound"
                }
            }

            if ($Normalized.ContainsKey('Minimum') -and
                $Normalized.ContainsKey('Maximum') -and
                $Normalized.Minimum -gt $Normalized.Maximum
            ) {
                throw [ArgumentException]::new(
                    "setting '$Name' Minimum $($Normalized.Minimum) exceeds Maximum $($Normalized.Maximum)."
                )
            }

            if ($Normalized.ContainsKey('Minimum') -and
                $Normalized.Default -lt $Normalized.Minimum
            ) {
                throw [ArgumentException]::new(
                    "setting '$Name' Default $($Normalized.Default) is below Minimum $($Normalized.Minimum)."
                )
            }

            if ($Normalized.ContainsKey('Maximum') -and
                $Normalized.Default -gt $Normalized.Maximum
            ) {
                throw [ArgumentException]::new(
                    "setting '$Name' Default $($Normalized.Default) exceeds Maximum $($Normalized.Maximum)."
                )
            }

            $Schema[$Name] = $Normalized
        }

        return $Schema
    } catch {
        $Exception = [ArgumentException]::new(
            "Invalid settings schema for Nitpick rule '$RuleId': $($_.Exception.Message)",
            $_.Exception
        )

        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $Exception,
            'NitpickInvalidRuleSettingsSchema',
            [ErrorCategory]::InvalidData,
            $RuleId
        ))
    }
}
