using namespace System
using namespace System.Collections
using namespace System.Management.Automation

<#
.SYNOPSIS
    Reads one explicitly selected PSD1 file as validated Nitpick project configuration.

.DESCRIPTION
    Reads one explicitly selected PSD1 file and returns a hashtable with optional
    Compatibility policy, Modules, and Rules settings keys.

    Resolves the configuration path against the caller's current location.

    Modules lists rule packages to acquire, as one string or an array of strings.
    A path-shaped entry (one containing a path separator or provider qualifier, or
    ending in .psd1, .psm1, or .dll) that is relative resolves from the
    configuration file's directory, so the configuration means the same thing
    wherever the command is run. Other entries are module names and are returned
    unchanged. Packages are not acquired here, so no module code runs.

    Rules is checked only for shape here, because which rule IDs exist depends on
    the packages loaded for a run. Resolve-NitpickEffectiveRuleSet checks the IDs
    and values against discovered rules.

    A PSD1 file that looks like a PowerShell module manifest is rejected with a
    specific message. The conventional configuration name, nitpick.psd1, matches
    Nitpick's own manifest on case-insensitive file systems.

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

.EXAMPLE
    Resolves a relative module path from the configuration file's directory.

    $Path = Join-Path $env:TEMP 'nitpick-example.psd1'
    Set-Content -LiteralPath $Path -Value "@{ Modules = 'WPF', '.\rules\Custom.psd1' }"
    (Read-NitpickConfiguration -LiteralPath $Path).Modules

    Returns 'WPF' unchanged and the absolute path of rules\Custom.psd1 under
    $env:TEMP. Neither module needs to exist, because nothing is imported.

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
        $Data = Copy-NitpickPlainData -Value $Data -Path 'Configuration'
        if ($Data -isnot [IDictionary]) {
            throw [ArgumentException]::new('Configuration must be a string-keyed dictionary.')
        }

        $ManifestKeys = @(
            @('ModuleVersion', 'RootModule', 'GUID') | Where-Object { $Data.Contains($_) }
        )
        if ($ManifestKeys.Count -gt 0) {
            throw [ArgumentException]::new(
                "the file looks like a PowerShell module manifest (it contains '$($ManifestKeys[0])'), " +
                'not a Nitpick configuration.'
            )
        }

        $Configuration = @{}
        foreach ($Key in $Data.psbase.Keys) {
            if ($Key -isnot [string] -or $Key -notin 'Compatibility', 'Modules', 'Rules') {
                throw [ArgumentException]::new("Unknown configuration key 'Configuration.$Key'.")
            }
        }

        if ($Data.Contains('Modules')) {
            $ConfigurationDirectory = Split-Path -Path $File.FullName -Parent
            $Modules = foreach ($Entry in @($Data.Modules)) {
                if ($Entry -isnot [string] -or [string]::IsNullOrWhiteSpace($Entry)) {
                    throw [ArgumentException]::new(
                        "'Configuration.Modules' must contain only non-empty module names or paths."
                    )
                }

                $IsPath = Test-NitpickModulePathShape -Value $Entry -SyntaxOnly

                if (-not $IsPath) {
                    if ([WildcardPattern]::ContainsWildcardCharacters($Entry)) {
                        throw [ArgumentException]::new(
                            "'Configuration.Modules' entry '$Entry' must be an exact module name, not a wildcard pattern."
                        )
                    }
                    $Entry
                } elseif ($Entry.Contains('::') -or [IO.Path]::IsPathRooted($Entry)) {
                    $Entry
                } else {
                    [IO.Path]::GetFullPath([IO.Path]::Combine($ConfigurationDirectory, $Entry))
                }
            }

            if (@($Modules).Count -gt 0) {
                $Configuration.Modules = [string[]] @($Modules)
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
