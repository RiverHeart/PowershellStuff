<#
.SYNOPSIS
    Removes whitespace from all strings up to the nearest non-whitespace value
    for any string.

.EXAMPLE
    Strip whitespace from all lines up to Line 1 and Line 4, preserving remaining
    whitespace on lines 2, 3, and 5.

    @"
        Line 1
            Line 2
                Line 3
        Line 4
            Line 5
"@ | Deindent-String
#>
function Dedent-String {
    [CmdletBinding()]
    [Alias('Deindent-String')]
    param(
        [Parameter(ValueFromPipeline)]
        [string[]] $String
    )

    process {
        foreach ($Str in $String) {
            $Lines = $Str -split '\r?\n'
            $MinIndent = $Lines |
                Where-Object { $_ -match '\S' } |
                ForEach-Object {
                    if ($_ -match "^(\s*)\S") {
                        $Matches[1].Length
                    } else {
                        0
                    }
                 } |
                Measure-Object -Minimum |
                Select-Object -ExpandProperty Minimum

            ($Lines | ForEach-Object {
                if ($MinIndent -gt 0 -and $_ -match "^(\s*)\S") {
                    $_.Substring($MinIndent)  # Get string starting from MinIndent
                } else {
                    $_
                }
            }) -join "`n"
        }
    }
}
