<#
.SYNOPSIS
    Formats the text of an AST node with optional truncation.

.DESCRIPTION
    The Format-AstText function takes a string of text and formats it
    by splitting it into lines and optionally truncating the number of
    lines and the length of each line.

.PARAMETER Text
    The text to format.

.PARAMETER MaxLines
    The maximum number of lines to include in the output. Default is 3.

.PARAMETER MaxLength
    The maximum length of each line. Default is 80.

.PARAMETER Prefix
    The prefix to prepend to each line.

.EXAMPLE
    Format the text of an AST node with a prefix.

{
    Write-Host 'Hello'
    Write-Host 'World'
}.Ast | Format-AstText -Prefix '>> '

.EXAMPLE
    Format the text of an AST node with a maximum number of lines and line length.

{ Write-Host 'Hello'
    Write-Host 'World'
}.Ast | Format-AstText -MaxLines 1 -MaxLineLength 5
#>
function Format-AstText {
    [CmdletBinding(DefaultParameterSetName = 'ByAst')]
    param(
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName = 'ByAst')]
        [Ast] $Ast,

        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName = 'ByText')]
        [string] $Text,

        [uint32] $MaxLines = 3,
        [uint32] $MaxLineLength = 80,
        [string] $Prefix
    )

    process {
        if ($PSBoundParameters['Ast']) {
            $Text = $Ast.Extent.Text
        }

        $Lines = $Text -split "\r?\n"
        if ($PSBoundParameters['MaxLines'] -and $Lines.Count -gt $MaxLines) {
            $Lines = $Lines[0..($MaxLines - 1)]
            $Lines += '...'
        }

        $Lines = $Lines | ForEach-Object {
            if ($PSBoundParameters['MaxLineLength'] -and $_.Length -gt $MaxLineLength) {
                $Prefix + $_.Substring(0, $MaxLineLength) + '...'
            } else {
                $Prefix + $_
            }
        }

        return $Lines -join "`n"
    }
}
