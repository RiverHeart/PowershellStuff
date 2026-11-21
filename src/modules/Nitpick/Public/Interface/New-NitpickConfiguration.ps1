using namespace System
using namespace System.Collections
using namespace System.Management.Automation

<#
.SYNOPSIS
    Validates Nitpick project configuration from in-memory data.

.DESCRIPTION
    Builds the same validated configuration that Start-Nitpicking -ConfigFile
    loads from a PSD1 file, without needing a file. It returns a hashtable with
    optional Compatibility, Modules, and Rules keys.

    Pass the whole configuration as a dictionary with -Data, or pass each section
    with -Compatibility, -Modules, and -Rules. The parameter names match the
    configuration keys, so a configuration hashtable can also be splatted.

    This is the only place configuration contents are checked;
    Read-NitpickConfiguration only reads the file and passes its data here. Keeping
    the checks separate from file access lets configuration be built and tested in
    memory.

    Modules lists rule packages to acquire, as one string or an array of strings.
    A path-shaped entry (one containing a path separator or provider qualifier, or
    ending in .psd1, .psm1, or .dll) that is relative resolves from BaseDirectory.
    Without BaseDirectory, relative module paths are rejected rather than resolved
    from the current location, because the same configuration would otherwise
    mean different things depending on where it is used. Other entries are module
    names and are returned unchanged. Packages are not acquired here, so no module
    code runs.

    Rules is checked only for shape, because which rule IDs exist depends on the
    packages loaded for a run. Start-Nitpicking checks the IDs and values against
    the discovered rules.

    Data that looks like a PowerShell module manifest (it contains ModuleVersion,
    RootModule, or GUID) is rejected with a specific message, so a module's own
    .psd1 is not mistaken for configuration. The conventional configuration name,
    nitpick.psd1, matches Nitpick's own manifest on case-insensitive file systems.

    The output is valid input, so passing a built configuration through again
    returns the same configuration. This is why Compatibility's MinimumVersion
    also accepts a two-component System.Version such as [version] '5.1', and why
    Start-Nitpicking -ConfigData can accept either raw data or a built
    configuration.

    Empty configuration returns an empty hashtable. Invalid or unknown
    configuration terminates with NitpickInvalidConfiguration.

.PARAMETER Data
    The whole configuration as a dictionary, such as the result of
    Import-PowerShellDataFile or ConvertFrom-PowerShellData.

.PARAMETER Compatibility
    The Compatibility section, for example @{ PowerShell = @{ MinimumVersion = '5.1' } }.

.PARAMETER Modules
    The rule packages to declare, as module names or paths.

.PARAMETER Rules
    Rule settings keyed by qualified rule ID, for example
    @{ 'Nitpick/AvoidLongLines' = @{ MaximumLength = 100 } }.

.PARAMETER BaseDirectory
    The directory that relative module paths resolve from. A relative
    BaseDirectory resolves from the current location.

.EXAMPLE
    Builds a configuration from individual sections.

    $Configuration = New-NitpickConfiguration `
        -Compatibility @{ PowerShell = @{ MinimumVersion = '5.1' } } `
        -Rules @{ 'Nitpick/AvoidLongLines' = @{ MaximumLength = 100 } }
    $Configuration.Compatibility.PowerShell.MinimumVersion

    Returns the System.Version 5.1.

.EXAMPLE
    Validates PSD1 text without writing it to disk.

    $Data = ConvertFrom-PowerShellData -String "@{ Modules = 'WPF', '.\rules\Custom.psd1' }"
    (New-NitpickConfiguration -Data $Data -BaseDirectory $env:TEMP).Modules

    Returns 'WPF' unchanged and the absolute path of rules\Custom.psd1 under
    $env:TEMP. Neither module needs to exist, because nothing is imported.

.EXAMPLE
    Rejects a relative module path when no base directory is given.

    New-NitpickConfiguration -Modules '.\rules\Custom.psd1'

    Throws NitpickInvalidConfiguration, explaining that the relative path needs
    -BaseDirectory or an absolute path.

.NOTES
    Validated configuration does not run rules or enable compatibility checking
    by itself; pass it to Start-Nitpicking -ConfigData.
#>
function New-NitpickConfiguration {
    [CmdletBinding(DefaultParameterSetName='Section')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory,ParameterSetName='Data')]
        [IDictionary] $Data,

        [Parameter(ParameterSetName='Section')]
        [AllowNull()]
        [object] $Compatibility,

        [Parameter(ParameterSetName='Section')]
        [AllowNull()]
        [object] $Modules,

        [Parameter(ParameterSetName='Section')]
        [AllowNull()]
        [object] $Rules,

        [string] $BaseDirectory
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'Section') {
            $Data = @{}
            foreach ($Key in 'Compatibility', 'Modules', 'Rules') {
                if ($PSBoundParameters.ContainsKey($Key)) {
                    $Data[$Key] = $PSBoundParameters[$Key]
                }
            }
        }

        $Data = Copy-NitpickPlainData -Value $Data -Path 'Configuration'

        $ManifestKeys = @(
            @('ModuleVersion', 'RootModule', 'GUID') | Where-Object { $Data.Contains($_) }
        )
        if ($ManifestKeys.Count -gt 0) {
            throw [ArgumentException]::new(
                "the data looks like a PowerShell module manifest (it contains '$($ManifestKeys[0])'), " +
                'not a Nitpick configuration.'
            )
        }

        foreach ($Key in $Data.psbase.Keys) {
            if ($Key -notin 'Compatibility', 'Modules', 'Rules') {
                throw [ArgumentException]::new("Unknown configuration key 'Configuration.$Key'.")
            }
        }

        $Configuration = @{}

        if ($Data.Contains('Modules')) {
            $ResolvedBaseDirectory = if ($BaseDirectory) {
                $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BaseDirectory)
            }

            $ModuleList = foreach ($Entry in @($Data.Modules)) {
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
                    Write-Output $Entry
                } elseif ($Entry.Contains('::') -or [IO.Path]::IsPathRooted($Entry)) {
                    Write-Output $Entry
                } elseif ($ResolvedBaseDirectory) {
                    Write-Output ([IO.Path]::GetFullPath([IO.Path]::Combine($ResolvedBaseDirectory, $Entry)))
                } else {
                    throw [ArgumentException]::new(
                        "'Configuration.Modules' entry '$Entry' is a relative path; " +
                        'pass -BaseDirectory or use an absolute path.'
                    )
                }
            }

            if ($ModuleList.Count -gt 0) {
                $Configuration.Modules = [string[]] @($ModuleList)
            }
        }

        if ($Data.Contains('Compatibility')) {
            # AllowVersion accepts this function's own [version] output, so validation can be repeated.
            $Policy = ConvertTo-NitpickPolicy -AllowVersion -Policy @{ Compatibility = $Data.Compatibility }
            if ($Policy.ContainsKey('Compatibility')) {
                $Configuration.Compatibility = $Policy.Compatibility
            }
        }

        if ($Data.Contains('Rules')) {
            if ($null -eq $Data.Rules) {
                throw [ArgumentException]::new("'Configuration.Rules' must be a dictionary keyed by qualified rule ID.")
            }

            $RuleSettings = ConvertTo-NitpickRuleSettingsMap `
                -RuleSettings $Data.Rules `
                -Source 'Configuration.Rules' `
                -ErrorAction Stop

            if ($RuleSettings.Count -gt 0) {
                $Configuration.Rules = $RuleSettings
            }
        }
    } catch {
        $Exception = [ArgumentException]::new(
            "Invalid Nitpick configuration: $($_.Exception.Message)",
            $_.Exception
        )

        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $Exception,
            'NitpickInvalidConfiguration',
            [ErrorCategory]::InvalidData,
            $null
        ))
    }

    # Output outside the try so downstream pipeline errors aren't reported as invalid configuration.
    Write-Output $Configuration
}
