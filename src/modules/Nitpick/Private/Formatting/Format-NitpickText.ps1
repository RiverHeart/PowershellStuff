using namespace System
using namespace System.Management.Automation.Language
using namespace System.Text

<#
.SYNOPSIS
    Formats findings and corrections for one Nitpick target as console-friendly text.

.DESCRIPTION
    Formats one target as a single section: the target path as a header, its findings
    sorted as given, and, when CorrectionResult is provided, the correction section
    from Format-NitpickCorrection. Returns nothing when there are no findings and no
    correction activity to report. Spacing between targets is left to the caller.

    ANSI OSC 8 hyperlinks are used by default when supported but can be explicitly
    enabled or disabled using `$env:FORCE_HYPERLINK` and `$env:NO_HYPERLINK`
    respectively. Hyperlinks allow multiple findings to be succintly aggregated
    beneath the file URI, making it easier to review findings without giving up
    the linking afforded by standard `filepath:line:column` references.

.PARAMETER Ast
    The parsed target. Its file path, or '<ScriptBlock>' for in-memory input, is the
    section header.

.PARAMETER Finding
    The findings to list beneath the header.

.PARAMETER CorrectionResult
    The NitpickCorrectionResult for the target, when corrections were requested.

.EXAMPLE
    Format findings for a specific AST and display them as console-friendly text

    $Ast = {}.Ast
    $Finding = New-NitpickFinding `
        -RuleName 'MyRule' `
        -Message 'This is a test message' `
        -ViolationExtent $extent `
        -Severity 'Warning' `
        -RuleSuppressionID 'None' `
        -Corrections @() `
        -OutputAs 'NitpickFinding'

    Format-NitpickText -Ast $Ast -Finding $Finding
#>
function Format-NitpickText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlockAst] $Ast,

        [Parameter()]
        [AllowEmptyCollection()]
        [object[]] $Finding = @(),

        [Parameter()]
        [NitpickCorrectionResult] $CorrectionResult
    )

    $CorrectionText = if ($CorrectionResult) {
        Format-NitpickCorrection -CorrectionResult $CorrectionResult
    }

    if ($Finding.Count -eq 0 -and -not $CorrectionText) {
        return
    }

    if ($Ast.Extent.File) {
        $FilePath = $Ast.Extent.File
        $UriPath = [Uri]::new($Ast.Extent.File)
    } else {
        $FilePath = '<ScriptBlock>'
        $UriPath = $null
    }

    $Builder = [StringBuilder]::new()
    $Builder.AppendLine($FilePath) | Out-Null

    # Convert each finding into a structured row for display so we can calculate
    # column widths
    $Rows = foreach ($Item in $Finding) {
        # Use ansi escape codes to turn line:column text into a hyperlink. Preferable over
        # the typical path:line:column format when aggregating multiple findings.
        $Position = "$($Item.ViolationExtent.StartLineNumber):$($Item.ViolationExtent.StartColumnNumber)"

        # A colon cannot be used to separate the file from the position because the URI
        # format reserves it for the scheme (e.g., file://) or port specification.
        # To workaround this, a hash (#) is used to create a fragment identifier so
        # the parser can correctly interpret the position within the file.
        if ($UriPath) {
            $Position = Format-NitpickHyperlink -Uri "$($UriPath.AbsoluteUri)#$Position" -Text $Position
        }

        [pscustomobject]@{
            Position = $Position
            Severity = $Item.Severity.ToLowerInvariant()
            Message = $Item.Message
            RuleLabel = Get-NitpickRuleLabel -InputObject $Item
        }
    }

    $Rows = @($Rows)
    if ($Rows.Count -gt 0) {
        $PositionWidth = ($Rows.Position | Measure-Object -Property Length -Maximum).Maximum
        $SeverityWidth = ($Rows.Severity | Measure-Object -Property Length -Maximum).Maximum
        $MessageWidth = ($Rows.Message | Measure-Object -Property Length -Maximum).Maximum
    }

    foreach ($Row in $Rows) {
        $Builder.AppendLine(('  {0}  {1}  {2}  {3}' -f `
            $Row.Position.PadRight($PositionWidth),
            $Row.Severity.PadRight($SeverityWidth),
            $Row.Message.PadRight($MessageWidth),
            $Row.RuleLabel
        )) | Out-Null
    }

    if ($CorrectionText) {
        if ($Finding.Count -gt 0) {
            $Builder.AppendLine() | Out-Null
        }
        $Builder.AppendLine($CorrectionText) | Out-Null
    }

    # Drop the final AppendLine terminator so callers control block spacing.
    return $Builder.ToString().TrimEnd("`r", "`n")
}
