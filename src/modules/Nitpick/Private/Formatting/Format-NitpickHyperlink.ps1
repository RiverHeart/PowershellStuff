using namespace System

<#
.SYNOPSIS
    Wraps console text in an ANSI OSC 8 hyperlink when the terminal should use one.

.DESCRIPTION
    Returns the text wrapped in an OSC 8 hyperlink targeting the URI, or the text
    unchanged when hyperlinks should not be used. Hyperlinks are used by default when
    the host supports virtual terminal sequences, except in VS Code, whose terminal
    link detection already resolves plain paths and trailing line:column positions.

    `$env:FORCE_HYPERLINK = '1'` always enables hyperlinks. `$env:FORCE_HYPERLINK = '0'`
    or `$env:NO_HYPERLINK = '1'` disables them. Text is always returned unchanged when
    no URI is supplied.

.PARAMETER Uri
    The hyperlink target, emitted as its absolute URI. Local paths become file URIs.
    When null, the text is returned unchanged.

.PARAMETER Text
    The visible text.

.EXAMPLE
    Link a file path to its file URI.

    Format-NitpickHyperlink -Uri 'C:\Scripts\Example.ps1' -Text 'C:\Scripts\Example.ps1'

.EXAMPLE
    Link a line:column position to its location within the file.

    $FileUri = [Uri]::new('C:\Scripts\Example.ps1').AbsoluteUri
    Format-NitpickHyperlink -Uri "$FileUri#3:5" -Text '3:5'
#>
function Format-NitpickHyperlink {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [AllowNull()]
        [Uri] $Uri,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text
    )

    if (-not $Uri) {
        return $Text
    }

    $IsVSCode = $env:TERM_PROGRAM -eq 'vscode'
    $SupportsAnsiLinks = $Host.UI.SupportsVirtualTerminal -or $IsVSCode

    # VS Code link detection supports contextual lookahead, meaning it can infer a
    # position (line:column) as belonging to the last link it found. With this, ANSI
    # hyperlinks aren't necessary.
    # https://code.visualstudio.com/docs/terminal/basics#_links
    $SupportsContextualLookahead = $IsVSCode

    $ShouldUseAnsiLinks = $env:FORCE_HYPERLINK -eq '1' -or (
        $SupportsAnsiLinks -and
        -not $SupportsContextualLookahead -and
        $env:FORCE_HYPERLINK -ne '0' -and
        $env:NO_HYPERLINK -ne '1'
    )

    if (-not $ShouldUseAnsiLinks) {
        return $Text
    }

    # Built by concatenation because interpolation mishandles the escape before '\'.
    $Esc = [string] [char] 27
    $Esc + ']8;;' + $Uri.AbsoluteUri + $Esc + '\' + $Text + $Esc + ']8;;' + $Esc + '\'
}
