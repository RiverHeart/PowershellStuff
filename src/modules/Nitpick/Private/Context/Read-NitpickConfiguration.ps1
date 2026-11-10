using namespace System.Management.Automation

<#
.SYNOPSIS
    Reads one explicitly selected PSD1 file as validated Nitpick project policy.

.DESCRIPTION
    Reads one explicitly selected PSD1 file as validated Nitpick project policy.

    Resolves filesystem paths against the caller's current location.

    Empty policy normalizes to an empty dictionary. Missing, unreadable, invalid,
    or unknown configuration terminates with NitpickInvalidConfiguration.

.PARAMETER Path
    The explicit configuration path; nitpick.psd1 is a convention, not a requirement.

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

    try {
        $ResolveParam = @{}
        if ($LiteralPath) {
            $ResolveParam.LiteralPath = $LiteralPath
        } else {
            $ResolveParam.Path = $Path
        }
        $Resolved = Resolve-Path @ResolveParam -ErrorAction Stop

        if ($Resolved.Provider.Name -ne 'FileSystem') {
            throw [ArgumentException]::new("Configuration '$Path' must be a filesystem file.")
        }

        $File = Get-Item -LiteralPath $Resolved.ProviderPath -ErrorAction Stop

        if ($File.PSIsContainer) {
            throw [ArgumentException]::new("Configuration '$Path' must be a file, not a directory.")
        }

        $Data = Import-PowerShellDataFile -LiteralPath $Resolved.ProviderPath -ErrorAction Stop
        $Data = Copy-NitpickContextValue -Value $Data -Path 'Policy'

        return ConvertTo-NitpickPolicy -Policy $Data
    } catch {
        $Exception = [ArgumentException]::new("Invalid Nitpick configuration '$Path': $($_.Exception.Message)", $_.Exception)
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $Exception, 'NitpickInvalidConfiguration',
            [ErrorCategory]::InvalidData,
            $Path
        ))
    }
}
