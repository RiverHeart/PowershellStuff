using namespace System
using namespace System.Management.Automation.Language
using namespace System.Text

<#
.SYNOPSIS
    Formats findings for one Nitpick target as console-friendly text.

.DESCRIPTION
    Formats findings for one Nitpick target as console-friendly text.

    ANSI OSC 8 hyperlinks are used by default when supported but can be explicitly
    enabled or disabled using `$env:FORCE_HYPERLINK` and `$env:NO_HYPERLINK`
    respectively. Hyperlinks allow multiple findings to be succintly aggregated
    beneath the file URI, making it easier to review findings without giving up
    the linking afforded by standard `filepath:line:column` references.

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

        [Parameter(Mandatory)]
        [object[]] $Finding
    )

    $Esc = [char] 27

    if ($Ast.Extent.File) {
        $FilePath = $Ast.Extent.File
        $UriPath = [Uri]::new($Ast.Extent.File)
    } else {
        $FilePath = '<ScriptBlock>'
        $UriPath = $null
    }

    $IsVSCode = $env:TERM_PROGRAM -eq 'vscode'

    # Determine if ANSI OSC 8 hyperlinks are supported or required
    $SupportsAnsiLinks = $Host.UI.SupportsVirtualTerminal -or $IsVSCode

    # VSCode link detection supports contextual lookahead, meaning
    # it can infer a position (line:column) as belonging to the last link it
    # found. With this, ANSI hyperlinks aren't necessary.
    # https://code.visualstudio.com/docs/terminal/basics#_links
    $SupportsContextualLookahead = $IsVSCode

    $ShouldUseAnsiLinks =
        $UriPath -and (
            # Force hyperlink if explicitly requested
            $env:FORCE_HYPERLINK -eq '1' -or
            (
                # Links are supported and not explicitly disabled
                $SupportsAnsiLinks -and
                -not $SupportsContextualLookahead -and
                $env:FORCE_HYPERLINK -ne '0' -and
                $env:NO_HYPERLINK -ne '1'
            )
        )

    $Builder = [StringBuilder]::new()
    $Builder.AppendLine($FilePath) | Out-Null

    # Convert each finding into a structured row for display so we can calculate
    # column widths
    $Rows = foreach ($Item in $Finding) {
        # Use ansi escape codes to turn line:column text into a hyperlink. Preferable over
        # the typical path:line:column format when aggregating multiple findings.
        $Position = "$($Item.ViolationExtent.StartLineNumber):$($Item.ViolationExtent.StartColumnNumber)"

        if ($ShouldUseAnsiLinks) {
            # A colon cannot be used to separate the file from the position because the URI
            # format reserves it for the scheme (e.g., file://) or port specification.
            # To workaround this, a hash (#) is used to create a fragment identifier so
            # the parser can correctly interpret the position within the file.
            $Position = [string] $Esc + ']8;;' + $UriPath.AbsoluteUri + '#' + $Position +
                [string] $Esc + '\' + $Position + [string] $Esc + ']8;;' + [string] $Esc + '\'
        }

        [pscustomobject]@{
            Position = $Position
            Severity = $Item.Severity.ToLowerInvariant()
            Message = $Item.Message
            RuleLabel = Get-NitpickRuleLabel -InputObject $Item
        }
    }

    $PositionWidth = ($Rows.Position | Measure-Object -Property Length -Maximum).Maximum
    $SeverityWidth = ($Rows.Severity | Measure-Object -Property Length -Maximum).Maximum
    $MessageWidth = ($Rows.Message | Measure-Object -Property Length -Maximum).Maximum

    foreach ($Row in $Rows) {
        $Builder.AppendLine(('  {0}  {1}  {2}  {3}' -f `
            $Row.Position.PadRight($PositionWidth),
            $Row.Severity.PadRight($SeverityWidth),
            $Row.Message.PadRight($MessageWidth),
            $Row.RuleLabel
        )) | Out-Null
    }

    return $Builder.ToString()
}
