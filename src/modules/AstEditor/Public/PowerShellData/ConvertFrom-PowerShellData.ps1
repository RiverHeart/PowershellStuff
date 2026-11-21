using namespace System
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Converts a string containing PowerShell data to its value.

.DESCRIPTION
    Parses a PowerShell string and safely evaluates its first hashtable. This
    supports in-memory configuration without writing the data to a temporary file.

.PARAMETER String
    The PowerShell source text containing a hashtable.

.PARAMETER SkipLimitCheck
    Skips the built-in safe evaluation limits. This is available only in PowerShell 7 or later.

.EXAMPLE
    ConvertFrom-PowerShellData -String "@{ Key = 'Value' }"

    Returns a hashtable whose Key value is 'Value'.

.NOTES
    This is the string-based counterpart to Import-PowerShellDataFile. Parse,
    no-hashtable, and safe evaluation failures have stable ErrorIds. Only the
    translated error is emitted; ErrorVariable can also collect caught exceptions.
#>
function ConvertFrom-PowerShellData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $String,

        [Parameter(HelpMessage="Skips the built-in safe evaluation limits.")]
        [switch] $SkipLimitCheck
    )

    begin {
        if ($SkipLimitCheck -and $PSVersionTable.PSVersion -lt [Version] '7.0') {
            $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
                [NotSupportedException]::new(
                    'Skipping the safe evaluation limit check requires PowerShell 7 or later.'
                ),
                'AstEditorPowerShellDataSkipLimitCheckNotSupported',
                [ErrorCategory]::NotImplemented,
                $null
            ))
        }
    }

    process {
        $ParseErrors = @()
        $Tokens = @()
        $Ast = [Parser]::ParseInput($String, [ref] $Tokens, [ref] $ParseErrors)

        if ($ParseErrors.Count -gt 0) {
            $WriteErrorParams = @{
                Exception    = [InvalidDataException]::new($ParseErrors[0].Message)
                ErrorId      = 'AstEditorPowerShellDataInvalidSyntax'
                Category     = [ErrorCategory]::ParserError
                TargetObject = $String
            }
            Write-Error @WriteErrorParams
        } else {
            $Data = $Ast.Find({
                param($Node) $Node -is [HashtableAst]
            }, $false)
        }

        if ($ParseErrors.Count -eq 0 -and $null -eq $Data) {
            $WriteErrorParams = @{
                Exception    = [InvalidDataException]::new('No valid hashtable found in string.')
                ErrorId      = 'AstEditorPowerShellDataNoHashtable'
                Category     = [ErrorCategory]::InvalidData
                TargetObject = $String
            }
            Write-Error @WriteErrorParams
        }

        if ($ParseErrors.Count -eq 0 -and $null -ne $Data) {
            $Exception = $null
            try {
                if ($SkipLimitCheck) {
                    $Value = $Data.SafeGetValue($true)
                } else {
                    $Value = $Data.SafeGetValue()
                }
            } catch {
                $Exception = $_.Exception
                if ($Exception.InnerException) {
                    $Exception = $Exception.InnerException
                }
            }

            # Keep output outside the try so downstream pipeline errors are not misreported as evaluation failures.
            if ($Exception) {
                $WriteErrorParams = @{
                    Exception    = $Exception
                    ErrorId      = 'AstEditorPowerShellDataEvaluationFailed'
                    Category     = [ErrorCategory]::InvalidData
                    TargetObject = $String
                }
                Write-Error @WriteErrorParams
            } else {
                Write-Output $Value
            }
        }
    }
}
