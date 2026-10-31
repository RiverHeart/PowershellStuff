using namespace System.Text
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Appends diff text with optional sequential line numbers and color
    to a builder.

.DESCRIPTION
    Accepts one raw text string per pipeline item or through -Text,
    including embedded line terminators. Empty text emits no lines,
    blank lines are preserved, and only the final line terminator is
    omitted.

    Appends to the builder without emitting pipeline output.
    Optional block-relative, end-exclusive AnnotationSpans add one
    caret row per affected start line, merging spans and preserving prefix tabs.

.NOTES
    Empty text is different from a blank line. Per the table
    below, the distinction is whether the input contains a line
    terminator.

    /===============================================================\
    | Raw Input    | Interpretation              | Displays As      |
    |==============+=============================+==================|
    | ''           | No text at all              | None             |
    |--------------+-----------------------------+------------------|
    | "`n"         | One blank, terminated line  | ''               |
    |--------------+-----------------------------+------------------|
    | "one`n"      | One terminated line         | 'one'            |
    |--------------+-----------------------------+------------------|
    | "one`n`n"    | One text line followed by a | 'one', ''        |
    |              | blank line                  |                  |
    |--------------+-----------------------------+------------------|
    | "one`n`ntwo" | A blank line between two    | 'one', '', 'two' |
    |              | text lines                  |                  |
    \--------------+-----------------------------+------------------/

    Empty input occurs naturally in a diff:

    * Inserting into an empty document means the original text is ''.
    * Deleting a whole block means its replacement text is ''.

    Neither should produce a placeholder - or + line.

    The order of operations is important:

    ```powershell
    $Lines   = @("one`ntwo`n")
    $Text    = "one`ntwo`n"
    $Trimmed = "one`ntwo"
    $Line    = "one", then "two"
    ```

    For "`n", the original input is **not empty**, so it passes the check.
    Removing its final terminator leaves '', which the split produces as one
    blank display line. That blank line is deliberately preserved.

    Removing the final terminator also prevents "one`n" from being interpreted as
    'one' plus an extra phantom line.
#>
function Add-AstDiffLine {
    [OutputType([void])]
    param (
        [Parameter(Mandatory)]
        [StringBuilder] $Builder,

        [Parameter(Mandatory)]
        [int] $GutterWidth,

        [Parameter(Mandatory)]
        [string] $Marker,

        [Parameter(Mandatory,ValueFromPipeline)]
        [AllowEmptyString()]
        [string] $Text,

        [Nullable[int]] $LineNumber,

        [ValidateSet('Red', 'Green')]
        [string] $Color,

        [object[]] $AnnotationSpans = @(),

        [switch] $NoColor
    )

    begin {
        $ColorIsDisabled = $NoColor -or $env:NO_COLOR
        if ($Color -and -not $ColorIsDisabled) {
            $Esc = [char]27
            $Red = "$Esc[31m"
            $Green = "$Esc[32m"
            $Reset = "$Esc[0m"
        } else {
            $Red = ''
            $Green = ''
            $Reset = ''
        }

        $ColorCode = switch ($Color) {
            'Red' { $Red }
            'Green' { $Green }
            default { '' }
        }

        $LineTerminatorPattern = '\r\n|\n|\r'
    }

    process {
        if ($Text.Length -gt 0) {
            $Annotations = [Dictionary[int, List[object]]]::new()
            if ($AnnotationSpans.Count -gt 0) {
                $Records = Get-AstTextLine -Text $Text
                foreach ($Span in $AnnotationSpans) {
                    if ($Span.End -le $Span.Start) {
                        continue
                    }

                    $StartLine = Get-AstLineIndexFromOffset -LineRecords $Records -Offset $Span.Start
                    $Record = $Records[$StartLine]
                    $Column = [Math]::Min($Span.Start, $Record.ContentEnd) - $Record.Start
                    $EndColumn = [Math]::Max(
                        $Column + 1,
                        [Math]::Min($Span.End, $Record.ContentEnd) - $Record.Start
                    )
                    if (-not $Annotations.ContainsKey($StartLine)) {
                        $Annotations[$StartLine] = [List[object]]::new()
                    }
                    $Annotations[$StartLine].Add(@{ Start = $Column; End = $EndColumn })
                }
            }

            $Trimmed = $Text -replace "(?:$LineTerminatorPattern)\z", ''
            $LineIndex = 0
            foreach ($Line in ($Trimmed -split $LineTerminatorPattern)) {
                $Gutter =
                    if ($null -eq $LineNumber) { ' ' * $GutterWidth }
                    else { ($LineNumber).ToString().PadLeft($GutterWidth) }

                [void] $Builder.AppendLine("$ColorCode  $Gutter | $Marker ${Line}$Reset")

                if ($Annotations.ContainsKey($LineIndex)) {
                    $Spans = $Annotations[$LineIndex]
                    $Width = 0

                    foreach ($Span in $Spans) {
                        $Width = [Math]::Max($Width, $Span.End)
                    }

                    $Underline = (' ' * $Width).ToCharArray()

                    for ($Column = 0; $Column -lt [Math]::Min($Width, $Line.Length); $Column++) {
                        if ($Line[$Column] -eq "`t") {
                            $Underline[$Column] = [char]9
                        }
                    }

                    foreach ($Span in $Spans) {
                        for ($Column = $Span.Start; $Column -lt $Span.End; $Column++) {
                            $Underline[$Column] = '^'
                        }
                    }

                    [void] $Builder.AppendLine("  $(' ' * $GutterWidth) |   $(-join $Underline)")
                }

                $LineIndex++

                if ($null -ne $LineNumber) {
                    $LineNumber++
                }
            }
        }
    }
}
