<#
.SYNOPSIS
    Gets the direct children of an AST node.

.DESCRIPTION
    The Get-AstChildren function takes an AST node and returns all of its direct children.

.PARAMETER Ast
    The AST node whose children are to be retrieved.
#>
function Get-AstChildren {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [Ast] $Ast
    )

    process {
        $Ast.FindAll({
            param($Candidate)

            [object]::ReferenceEquals($Candidate.Parent, $Ast)
        }, $true)
    }
}
