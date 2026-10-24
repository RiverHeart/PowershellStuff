<#
.SYNOPSIS
    Formats findings for one Nitpick target as console-friendly text.
#>
function ConvertTo-NitpickText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.ScriptBlockAst] $Ast,

        [Parameter(Mandatory)]
        [object[]] $Finding
    )

    $DisplayPath = if ($Ast.Extent.File) {
        $Ast.Extent.File
    } else {
        '<ScriptBlock>'
    }

    $Rows = @(
        foreach ($Item in $Finding) {
            [pscustomobject]@{
                Position = '{0}:{1}' -f `
                    $Item.ViolationExtent.StartLineNumber,
                    $Item.ViolationExtent.StartColumnNumber
                Severity = $Item.Severity.ToLowerInvariant()
                Message = $Item.Message
                RuleName = $Item.RuleName
            }
        }
    )

    $PositionWidth = ($Rows.Position | Measure-Object -Property Length -Maximum).Maximum
    $SeverityWidth = ($Rows.Severity | Measure-Object -Property Length -Maximum).Maximum
    $MessageWidth = ($Rows.Message | Measure-Object -Property Length -Maximum).Maximum
    $Lines = foreach ($Row in $Rows) {
        '  {0}  {1}  {2}  {3}' -f `
            $Row.Position.PadRight($PositionWidth),
            $Row.Severity.PadRight($SeverityWidth),
            $Row.Message.PadRight($MessageWidth),
            $Row.RuleName
    }

    return (@($DisplayPath) + $Lines) -join [Environment]::NewLine
}
