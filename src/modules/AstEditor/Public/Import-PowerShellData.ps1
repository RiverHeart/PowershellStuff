using namespace System
using namespace System.IO
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Imports PowerShell data from a file, literal path, or string containing a hashtable.

.DESCRIPTION
    Imports PowerShell data from a file, literal path, or string containing a hashtable.

.EXAMPLE
    Import data from a file.

    Import-PowerShellData -Path "C:\data.psd1"

.EXAMPLE
    Import data from a string.

    Import-PowerShellData -String "@{ Key = 'Value' }"

.NOTES
    Extension of the Import-PowerShellDataFile command as implemented in PowerShell.

    Intentionally refrains from using AstEditor cmdlets for easy inclusion in other scripts.

    Source Link: https://github.com/PowerShell/PowerShell/blob/master/src/Microsoft.PowerShell.Commands.Utility/commands/utility/ImportPowerShellDataFile.cs
#>
function Import-PowerShellData {
    [CmdletBinding(DefaultParameterSetName='Path')]
    param(
        [Parameter(Mandatory,ParameterSetName='Path')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [Parameter(Mandatory,ParameterSetName='LiteralPath',ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('PSPath', 'LP')]
        [string[]] $LiteralPath,

        [Parameter(Mandatory,ParameterSetName='String')]
        [ValidateNotNullOrEmpty()]
        [string] $String,

        [Parameter(HelpMessage="Gets or sets switch that determines if built-in limits are applied to the data.")]
        [switch] $SkipLimitCheck
    )

    process {
        $IsLiteralPath = $PSCmdlet.ParameterSetName -eq 'LiteralPath'
        $InputObject = switch ($PSCmdlet.ParameterSetName) {
            'Path' { $Path }
            'LiteralPath' { $LiteralPath }
            'String' { $String }
        }

        foreach ($InputItem in $InputObject) {
            $ParseErrors = @()
            $Tokens = @()

            try {
                if ($PSCmdlet.ParameterSetName -eq 'String') {
                    $Data = [Parser]::ParseInput($InputItem, [ref] $Tokens, [ref] $ParseErrors).Find({
                        param($ast) $ast -is [HashtableAst]
                    }, $false)

                } else {
                    $ResolveParam = @{}
                    if ($IsLiteralPath) {
                        $ResolveParam.LiteralPath = $InputItem
                    } else {
                        $ResolveParam.Path = $InputItem
                    }
                    $Resolved = Resolve-Path @ResolveParam -ErrorAction Stop

                    if ($Resolved.Provider.Name -ne 'FileSystem') {
                        throw [ArgumentException]::new("Path '$InputItem' must be a filesystem file.")
                    }

                    $File = Get-Item -LiteralPath $Resolved.ProviderPath -ErrorAction Stop

                    if ($File.PSIsContainer) {
                        throw [ArgumentException]::new("Path '$InputItem' must be a file, not a directory.")
                    }

                    $Data = [Parser]::ParseFile($File.FullName, [ref] $Tokens, [ref] $ParseErrors).Find({
                        param($ast) $ast -is [HashtableAst]
                    }, $false)
                }

                if ($ParseErrors.Count -gt 0) {
                    throw [InvalidDataException]::new(($ParseErrors[0].Message -join "`n"))
                }

                if (-not $Data) {
                    if ($PSCmdlet.ParameterSetName -eq 'String') {
                        throw [InvalidDataException]::new("No valid hashtable found in string.")
                    } else {
                        throw [InvalidDataException]::new("No valid hashtable found in '$InputItem'.")
                    }
                }

                return $Data.SafeGetValue($SkipLimitCheck)

            } catch {
                throw [ArgumentException]::new("Failed to import PowerShell data: $($_.Exception.Message)")
            }
        }
    }
}
