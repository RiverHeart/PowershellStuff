using namespace System.Collections.Generic

<#
.SYNOPSIS
    Expands nested parser tokens into a source-ordered token list.

.DESCRIPTION
    The PowerShell parser stores tokens inside expandable-string subexpressions
    on StringExpandableToken.NestedTokens instead of in the top-level token
    stream. Expand-AstTokenTree returns both token levels so callers can search
    a single collection by kind and source extent.

.PARAMETER Token
    One or more parser tokens to expand.

.EXAMPLE
    $Tokens = $null
    $Errors = $null
    [void] [Parser]::ParseInput('"value: $($Value)"', [ref] $Tokens, [ref] $Errors)
    $AllTokens = @(Expand-AstTokenTree -Token $Tokens)

    Returns the expandable-string token and the tokens inside its subexpression
    in source order.
#>
function Expand-AstTokenTree {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.Token])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [System.Management.Automation.Language.Token[]] $Token
    )

    begin {
        $PendingTokens = [Queue[System.Management.Automation.Language.Token]]::new()
        $AllTokens = [List[System.Management.Automation.Language.Token]]::new()
    }

    process {
        foreach ($InputToken in $Token) {
            $PendingTokens.Enqueue($InputToken)
        }
    }

    end {
        while ($PendingTokens.Count -gt 0) {
            $CurrentToken = $PendingTokens.Dequeue()
            $AllTokens.Add($CurrentToken)

            if ($CurrentToken -is [System.Management.Automation.Language.StringExpandableToken]) {
                foreach ($NestedToken in $CurrentToken.NestedTokens) {
                    $PendingTokens.Enqueue($NestedToken)
                }
            }
        }

        $SortedTokens = @(
            $AllTokens |
                Sort-Object `
                    -Property @{ Expression = { $_.Extent.StartOffset } }, `
                    @{ Expression = { $_.Extent.EndOffset } }
        )
        foreach ($SortedToken in $SortedTokens) {
            Write-Output $SortedToken
        }
    }
}
