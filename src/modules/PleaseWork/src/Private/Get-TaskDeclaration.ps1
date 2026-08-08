using namespace System.Collections.Generic

<#
.SYNOPSIS
    Parses ordered task declarations from a scriptblock without invoking it.
#>
function Get-TaskDeclaration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    $SourceText = $ScriptBlock.Ast.Extent.Text
    $Tokens = $null
    $ParseErrors = $null
    $ParsedAst = [System.Management.Automation.Language.Parser]::ParseInput(
        $SourceText,
        [ref] $Tokens,
        [ref] $ParseErrors
    )
    $CommentTokens = @($Tokens | Where-Object {
            $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment
        })

    $TaskNames = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Statement in $ParsedAst.EndBlock.Statements) {
        # Only top-level, single-command pipelines can be task declarations.
        if (-not ($Statement -is [System.Management.Automation.Language.PipelineAst]) -or
            $Statement.PipelineElements.Count -ne 1 -or
            -not ($Statement.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst])
        ) {
            continue
        }

        $CommandAst = $Statement.PipelineElements[0]
        $CommandToken = $CommandAst.GetCommandName()
        # The trailing colon distinguishes task declarations from ordinary commands.
        if ([string]::IsNullOrEmpty($CommandToken) -or
            -not $CommandToken.EndsWith(':')
        ) {
            continue
        }

        $TaskName = $CommandToken.TrimEnd(':')
        if ([string]::IsNullOrEmpty($TaskName)) {
            throw 'Task names cannot be empty.'
        }
        if (-not $TaskNames.Add($TaskName)) {
            throw "Task '$TaskName' is declared more than once."
        }

        $CommandElements = $CommandAst.CommandElements
        if ($CommandElements.Count -lt 2 -or
            -not ($CommandElements[-1] -is [System.Management.Automation.Language.ScriptBlockExpressionAst])
        ) {
            throw "Task '$TaskName' must end with a scriptblock body."
        }

        $Dependencies = [List[string]]::new()
        $PathSpecs = [List[string]]::new()
        $ElementIndex = 1
        while ($ElementIndex -lt ($CommandElements.Count - 1)) {
            $DependencyAst = $CommandElements[$ElementIndex]
            if (
                -not ($DependencyAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) -or
                $DependencyAst.StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::BareWord
            ) {
                throw "Dependencies for task '$TaskName' must be bare task names."
            }

            if ($DependencyAst.Value -ine 'changed') {
                $Dependencies.Add($DependencyAst.Value)
                $ElementIndex++
                continue
            }

            $ElementIndex++
            if ($ElementIndex -ge ($CommandElements.Count - 1) -or
                -not ($CommandElements[$ElementIndex] -is [System.Management.Automation.Language.ParenExpressionAst])
            ) {
                throw "Changeset filter for task '$TaskName' must use changed('pathspec', ...)."
            }

            $FilterPipeline = $CommandElements[$ElementIndex].Pipeline
            if ($FilterPipeline.PipelineElements.Count -ne 1 -or
                -not ($FilterPipeline.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst])
            ) {
                throw "Changeset filters for task '$TaskName' must contain only string pathspecs."
            }

            $FilterExpression = $FilterPipeline.PipelineElements[0].Expression
            if ($FilterExpression -is [System.Management.Automation.Language.ArrayLiteralAst]) {
                $FilterElements = @($FilterExpression.Elements)
            } else {
                $FilterElements = @($FilterExpression)
            }

            if ($FilterElements.Count -eq 0) {
                throw "Changeset filter for task '$TaskName' must contain at least one pathspec."
            }
            foreach ($FilterElement in $FilterElements) {
                if (-not ($FilterElement -is [System.Management.Automation.Language.StringConstantExpressionAst]) -or
                    [string]::IsNullOrWhiteSpace($FilterElement.Value)
                ) {
                    throw "Changeset filters for task '$TaskName' must contain only string pathspecs."
                }
                $PathSpecs.Add($FilterElement.Value)
            }
            $ElementIndex++
        }

        $Comments = [List[string]]::new()
        $CommentBoundary = $CommandAst.Extent.StartOffset
        foreach ($CommentToken in ($CommentTokens |
                Where-Object { $_.Extent.EndOffset -le $CommentBoundary } |
                Sort-Object { $_.Extent.StartOffset } -Descending)) {
            $Gap = $SourceText.Substring(
                $CommentToken.Extent.EndOffset,
                $CommentBoundary - $CommentToken.Extent.EndOffset
            )
            if (-not [string]::IsNullOrWhiteSpace($Gap)) {
                break
            }

            $Comments.Insert(0, $CommentToken.Text)
            $CommentBoundary = $CommentToken.Extent.StartOffset
        }

        $TaskHelp = Get-TaskHelp -Comments $Comments.ToArray()
        [pscustomobject] @{
            Name = $TaskName
            CommandToken = $CommandToken
            Dependencies = $Dependencies.ToArray()
            PathSpecs = $PathSpecs.ToArray()
            Comments = $Comments.ToArray()
            Help = $TaskHelp
        }
    }
}
