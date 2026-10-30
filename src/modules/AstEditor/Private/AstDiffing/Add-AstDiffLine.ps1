using namespace System.Text

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
            $Trimmed = $Text -replace "(?:$LineTerminatorPattern)\z", ''
            foreach ($Line in ($Trimmed -split $LineTerminatorPattern)) {
                $Gutter =
                    if ($null -eq $LineNumber) { ' ' * $GutterWidth }
                    else { ($LineNumber).ToString().PadLeft($GutterWidth) }

                [void] $Builder.AppendLine("$ColorCode  $Gutter $Marker ${Line}$Reset")

                if ($null -ne $LineNumber) {
                    $LineNumber++
                }
            }
        }
    }
}
