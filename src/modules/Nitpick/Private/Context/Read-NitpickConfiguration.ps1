using namespace System
using namespace System.Collections
using namespace System.Management.Automation

<#
.SYNOPSIS
    Reads one explicitly selected PSD1 file as validated Nitpick project configuration.

.DESCRIPTION
    Reads one explicitly selected PSD1 file and returns a hashtable with optional
    Compatibility policy and Rules settings keys.

    Resolves filesystem paths against the caller's current location.

    Rules is checked only for shape here, because which rule IDs exist depends on
    the packages loaded for a run. Resolve-NitpickEffectiveRuleSet checks the IDs
    and values against discovered rules.

    Empty configuration normalizes to an empty dictionary. Missing, unreadable,
    invalid, or unknown configuration terminates with NitpickInvalidConfiguration.

.PARAMETER Path
    The explicit configuration path; nitpick.psd1 is a convention, not a requirement.

.PARAMETER LiteralPath
    The explicit configuration path, used exactly as written without wildcard expansion.

.EXAMPLE
    Loads the specified PSD1 file as a Nitpick configuration.

    $NitpickModule = Import-Module Nitpick -PassThru
    $NitpickModule.NewBoundScriptBlock({
        $Policy = Read-NitpickConfiguration -LiteralPath '.\build\policy[legacy].psd1'
    }).Invoke()

.NOTES
    Private helper; examples run within Nitpick's module scope. Loading policy
    alone does not run rules or enable compatibility checking.
#>
function Read-NitpickConfiguration {
    [CmdletBinding(DefaultParameterSetName='Path')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory,ParameterSetName='Path')]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Path,

        [Parameter(Mandatory,ParameterSetName='LiteralPath')]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $LiteralPath
    )

    $DisplayPath = if ($PSCmdlet.ParameterSetName -eq 'LiteralPath') { $LiteralPath } else { $Path }

    try {
        $ResolveParam = @{}
        if ($LiteralPath) {
            $ResolveParam.LiteralPath = $LiteralPath
        } else {
            $ResolveParam.Path = $Path
        }
        $Resolved = Resolve-Path @ResolveParam -ErrorAction Stop

        if ($Resolved.Provider.Name -ne 'FileSystem') {
            throw [ArgumentException]::new("Configuration '$DisplayPath' must be a filesystem file.")
        }

        $File = Get-Item -LiteralPath $Resolved.ProviderPath -ErrorAction Stop

        if ($File.PSIsContainer) {
            throw [ArgumentException]::new("Configuration '$DisplayPath' must be a file, not a directory.")
        }

        $Data = Import-PowerShellDataFile -LiteralPath $Resolved.ProviderPath -ErrorAction Stop
        $Data = Copy-NitpickContextValue -Value $Data -Path 'Configuration'
        if ($Data -isnot [IDictionary]) {
            throw [ArgumentException]::new('Configuration must be a string-keyed dictionary.')
        }

        $Configuration = @{}
        foreach ($Key in $Data.psbase.Keys) {
            if ($Key -isnot [string] -or $Key -notin 'Compatibility', 'Rules') {
                throw [ArgumentException]::new("Unknown configuration key 'Configuration.$Key'.")
            }
        }

        if ($Data.Contains('Compatibility')) {
            $Policy = ConvertTo-NitpickPolicy -Policy @{ Compatibility = $Data.Compatibility }
            if ($Policy.ContainsKey('Compatibility')) {
                $Configuration.Compatibility = $Policy.Compatibility
            }
        }

        if ($Data.Contains('Rules')) {
            if ($null -eq $Data.Rules) {
                throw [ArgumentException]::new("'Configuration.Rules' must be a dictionary keyed by qualified rule ID.")
            }

            # Only the map's shape is checked here; rule IDs and values are checked
            # against discovered descriptors by Resolve-NitpickEffectiveRuleSet.
            $RuleSettings = ConvertTo-NitpickRuleSettingsMap `
                -RuleSettings $Data.Rules `
                -Source 'Configuration.Rules' `
                -ErrorAction Stop

            if ($RuleSettings.Count -gt 0) {
                $Configuration.Rules = $RuleSettings
            }
        }

        return $Configuration
    } catch {
        $Exception = [ArgumentException]::new(
            "Invalid Nitpick configuration '$DisplayPath': $($_.Exception.Message)",
            $_.Exception
        )

        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $Exception, 'NitpickInvalidConfiguration',
            [ErrorCategory]::InvalidData,
            $DisplayPath
        ))
    }
}
