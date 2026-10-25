<#
.SYNOPSIS
    Splits text into line records with offsets for content and terminators.

.DESCRIPTION
    Returns one record per line. Start is the offset of the first character,
    ContentEnd is the offset of the line terminator (or the end of the text),
    and End is the offset of the next line. CRLF, LF, and CR terminators are
    recognized. Text ending with a terminator yields a final empty line whose
    Start equals the text length, so an end-of-text offset always maps to a line.

.EXAMPLE
    Get-AstTextLine -Text "first`r`nsecond"

    Returns records for 'first' (0, 5, 7) and 'second' (7, 13, 13).
#>
function Get-AstTextLine {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text
    )

    $Lines = [System.Collections.Generic.List[pscustomobject]]::new()
    $Start = 0
    foreach ($Match in [regex]::Matches($Text, '\r\n|\n|\r')) {
        $Lines.Add([pscustomobject]@{
            Start = $Start
            ContentEnd = $Match.Index
            End = $Match.Index + $Match.Length
        })
        $Start = $Match.Index + $Match.Length
    }

    $Lines.Add([pscustomobject]@{
        Start = $Start
        ContentEnd = $Text.Length
        End = $Text.Length
    })

    return , $Lines.ToArray()
}
