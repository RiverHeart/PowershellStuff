using namespace System
using namespace System.Collections
using namespace System.Management.Automation

<#
.SYNOPSIS
    Reads one explicitly selected PSD1 file as validated Nitpick project configuration.

.DESCRIPTION
    Resolves the configuration path against the caller's current location, reads
    the file as data, and passes it to New-NitpickConfiguration with the file's
    directory as the base directory. This function owns only the file handling;
    New-NitpickConfiguration owns every check on the contents, so the same rules
    apply to configuration built in memory.

    Passing the file's directory means relative module paths resolve from the
    configuration file, so the configuration means the same thing wherever the
    command is run.

    Missing, unreadable, invalid, or unknown configuration terminates with
    NitpickInvalidConfiguration, and the message names the configuration path.

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
        $ConfigurationDirectory = Split-Path -Path $File.FullName -Parent
        $Configuration = New-NitpickConfiguration -Data $Data -BaseDirectory $ConfigurationDirectory
    } catch {
        # New-NitpickConfiguration already says the configuration is invalid; add the path instead.
        $Cause = $_.Exception
        if ($_.FullyQualifiedErrorId -like 'NitpickInvalidConfiguration,*' -and $Cause.InnerException) {
            $Cause = $Cause.InnerException
        }

        $Exception = [ArgumentException]::new(
            "Invalid Nitpick configuration '$DisplayPath': $($Cause.Message)",
            $Cause
        )

        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $Exception, 'NitpickInvalidConfiguration',
            [ErrorCategory]::InvalidData,
            $DisplayPath
        ))
    }

    Write-Output $Configuration
}
