<#
.SYNOPSIS
    Gets trimmed statement text from a script block AST.

.DESCRIPTION
    Returns the top-level statement text from the EndBlock of a script block AST.
    This keeps semantic comparisons focused on parsed statements instead of raw text.
#>
function Get-ScriptBlockStatementText {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [ScriptBlockAst] $ScriptBlockAst
    )

    if ($null -eq $ScriptBlockAst.EndBlock) {
        return @()
    }

    $StatementText = [List[string]]::new()
    foreach ($Statement in $ScriptBlockAst.EndBlock.Statements) {
        [void] $StatementText.Add($Statement.Extent.Text.Trim())
    }

    Write-Output $StatementText.ToArray() -NoEnumerate
}