<#
.SYNOPSIS
    Parses comment-based help associated with a task.
#>
function Get-TaskHelp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Comments
    )

    if ($Comments.Count -eq 0) {
        return
    }

    $HelpSource = ($Comments -join [Environment]::NewLine) +
        "`nfunction __PleaseWorkTaskHelp {}`n"
    $HelpTokens = $null
    $HelpErrors = $null
    $HelpAst = [System.Management.Automation.Language.Parser]::ParseInput(
        $HelpSource,
        [ref] $HelpTokens,
        [ref] $HelpErrors
    )
    $FunctionAst = $HelpAst.Find({
            param ($AstNode)
            $AstNode -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $false)
    return $FunctionAst.GetHelpContent()
}
