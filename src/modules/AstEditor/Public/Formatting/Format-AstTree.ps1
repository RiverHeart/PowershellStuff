using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Formats an AST tree as a string.

.DESCRIPTION
    Converts a ScriptBlockAst into its string representation for easier visualization
    and debugging.

    Example:

    ScriptBlockAst
    `-- NamedBlockAst
        `-- PipelineAst
            `-- CommandAst: Write-Host 'Hello' *

.PARAMETER Ast
    The AST node to format.

.PARAMETER Depth
    The maximum depth to display.

.PARAMETER TruncateAt
    The maximum length of each text-preview line.

.PARAMETER TruncateLines
    The maximum number of text-preview lines to display per node.

.EXAMPLE
    Format an AST node as a tree.

    { Write-Host 'Hello' }.Ast | Format-AstTree
#>
function Format-AstTree {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [Ast] $Ast,

        [Parameter(HelpMessage='Maximum depth to display')]
        [int] $Depth = 4,

        [int] $TruncateAt = 80,
        [int] $TruncateLines = 4
    )

    process {
        Write-AstBranch `
            -Node $Ast `
            -Prefix '' `
            -DepthRemaining $Depth `
            -IsRoot `
            -MaxLines $TruncateLines `
            -MaxLineLength $TruncateAt `
            -IncludeText
    }
}


<#
.SYNOPSIS
    Writes an AST node and its children as a tree structure.

.DESCRIPTION
    The Write-AstBranch function recursively writes an AST node and its
    children as a tree structure, with optional depth control and
    multiline text handling.

.PARAMETER Node
    The AST node to write.

.PARAMETER Prefix
    The prefix to use for the current branch. Default is an empty string.

.PARAMETER DepthRemaining
    The remaining depth to traverse. Default is 4.

.PARAMETER IsRoot
    Indicates if the current node is the root of the tree.

.PARAMETER MaxLines
    The maximum number of text-preview lines to display per node.

.PARAMETER MaxLineLength
    The maximum length of each text-preview line.

.PARAMETER IncludeText
    Includes a preview of each node's extent text.
#>
function Write-AstBranch {
    param(
        [Ast] $Node,
        [string] $Prefix = '',
        [int] $DepthRemaining = 4,
        [switch] $IsRoot,
        [uint32] $MaxLines = 3,
        [uint32] $MaxLineLength = 80,
        [switch] $IncludeText
    )

    if ($IsRoot) {
        Write-Output $Node.GetType().Name
    }

    if ($DepthRemaining -le 0) {
        return
    }

    $Children = @(Get-AstChildren -Ast $Node)
    $LastIndex = $Children.Count - 1

    for ($Index = 0; $Index -lt $Children.Count; $Index++) {
        $Child = $Children[$Index]
        $IsLast = $Index -eq $LastIndex
        $Connector = if ($IsLast) { '`-- ' } else { '|-- ' }
        $BranchLine = $Prefix + $Connector + $Child.GetType().Name
        $ChildPrefix = $Prefix + $(if ($IsLast) { '    ' } else { '|   ' })

        if ($IncludeText) {
            $HasMultilineText = $Child.Extent.Text.IndexOf("`n") -ne -1
            $FormatParams = @{
                MaxLineLength = $MaxLineLength
                MaxLines  = $MaxLines
            }
            $NodeText = $Child | Format-AstText @FormatParams

            if ($HasMultilineText) {
                Write-Output $BranchLine
                $NodeText -split "`n" | ForEach-Object {
                    Write-Output ($ChildPrefix + '>> ' + $_.TrimStart())
                }
            } else {
                Write-Output "$BranchLine  <<  $NodeText"
            }
        } else {
            Write-Output $BranchLine
        }

        $WriteParams = @{
            Node = $Child
            Prefix = $ChildPrefix
            DepthRemaining = $DepthRemaining - 1
            IsRoot = $false
            MaxLines = $MaxLines
            MaxLineLength = $MaxLineLength
            IncludeText = $IncludeText
        }

        Write-AstBranch @WriteParams
    }
}
