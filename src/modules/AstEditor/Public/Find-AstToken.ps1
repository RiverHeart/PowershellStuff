<#
.SYNOPSIS
    Finds parser tokens in an AstDocument.

.DESCRIPTION
    Searches the document's flattened, source-ordered token view. Tokens nested
    inside expandable-string subexpressions are included without requiring
    callers to traverse StringExpandableToken.NestedTokens.

.PARAMETER Document
    The document whose submitted AST token view is searched.

.PARAMETER Kind
    Limits results to one or more token kinds.

.PARAMETER Query
    A predicate that receives each candidate token. A zero-value result is
    treated as false. Multiple emitted values are ambiguous and cause an error.

.PARAMETER All
    Returns every matching token instead of the first source-ordered match.

.PARAMETER Range
    Limits results to tokens fully contained in an IScriptExtent or in a
    zero-based, end-exclusive pair of offsets.

.EXAMPLE
    $Document = New-AstDocument -InputObject '! $Value'
    Find-AstToken -Document $Document -Kind Exclaim

    Returns the exclamation-mark token.

.EXAMPLE
    $Document = New-AstDocument -InputObject '"$(! $Value)"'
    Find-AstToken -Document $Document -Kind Exclaim

    Finds the token inside the expandable-string subexpression.
#>
function Find-AstToken {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.Token])]
    param(
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [System.Management.Automation.Language.TokenKind[]] $Kind,

        [scriptblock] $Query,

        [switch] $All,

        [object] $Range
    )

    $HasRange = $PSBoundParameters.ContainsKey('Range')
    if ($HasRange) {
        if ($Range -is [System.Management.Automation.Language.IScriptExtent]) {
            $StartOffset = $Range.StartOffset
            $EndOffset = $Range.EndOffset
        } elseif ($Range -is [array] -and $Range.Rank -eq 1 -and $Range.Count -eq 2 -and
            $Range[0] -is [int] -and $Range[1] -is [int]
        ) {
            $StartOffset = $Range[0]
            $EndOffset = $Range[1]
        } else {
            throw [ArgumentException]::new(
                'Range must be an IScriptExtent or a two-item integer offset range.'
            )
        }

        if ($StartOffset -lt 0 -or $EndOffset -lt $StartOffset) {
            throw [ArgumentException]::new(
                'Range offsets must be non-negative and ordered.'
            )
        }
    }

    $HasKind = $PSBoundParameters.ContainsKey('Kind')
    $HasQuery = $PSBoundParameters.ContainsKey('Query')
    if ($HasQuery) {
        $OriginalQuery = $Query
        $HasParamBlockParameters =
            $null -ne $OriginalQuery.Ast.ParamBlock -and
            $OriginalQuery.Ast.ParamBlock.Parameters.Count -gt 0

        if ($HasParamBlockParameters) {
            $EvaluateQuery = {
                param($Token)
                & $OriginalQuery $Token
            }
        } else {
            $EvaluateQuery = {
                param($Token)
                $Token | ForEach-Object $OriginalQuery
            }
        }
    }

    $Matches = @(
        foreach ($Token in $Document.Tokens) {
            if ($HasKind -and $Kind -notcontains $Token.Kind) {
                continue
            }

            if ($HasRange -and (
                $Token.Extent.StartOffset -lt $StartOffset -or
                $Token.Extent.EndOffset -gt $EndOffset
            )) {
                continue
            }

            if ($HasQuery) {
                $QueryOutput = @(& $EvaluateQuery $Token)
                if ($QueryOutput.Count -gt 1) {
                    throw [InvalidOperationException]::new(
                        "Token query emitted $($QueryOutput.Count) values for token kind '$($Token.Kind)'; expected zero or one."
                    )
                }

                if ($QueryOutput.Count -eq 0 -or -not [bool] $QueryOutput[0]) {
                    continue
                }
            }

            Write-Output $Token
            if (-not $All) {
                break
            }
        }
    )

    foreach ($Match in $Matches) {
        Write-Output $Match
    }
}
