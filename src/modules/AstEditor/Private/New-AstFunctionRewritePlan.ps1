<#
.SYNOPSIS
    Builds a validated rewrite plan for replacing one PowerShell function.

.DESCRIPTION
    Selects exactly one function by name and validates that Replacement contains
    exactly one complete function definition. Top-level functions are selected by
    default. Recurse includes nested function definitions. Contiguous comment-based
    help immediately above the target is included unless ExcludeHelp is specified.
#>
function New-AstFunctionRewritePlan {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-AstDocumentInstance -InputObject $_ })]
        [object] $Document,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Replacement,

        [switch] $Recurse,

        [switch] $ExcludeHelp
    )

    if ($Document.ParseErrors.Count -gt 0) {
        throw "Cannot edit a document with $($Document.ParseErrors.Count) existing parse error(s)."
    }

    $Candidates = @(
        $Document.Ast.FindAll({
            param($Node)

            if ($Node -isnot [FunctionDefinitionAst]) {
                return $false
            }

            if ($Node.Name -ine $Name) {
                return $false
            }

            if ($Recurse) {
                return $true
            }

            $Ancestor = $Node.Parent
            while ($null -ne $Ancestor) {
                if ($Ancestor -is [FunctionDefinitionAst]) {
                    return $false
                }
                $Ancestor = $Ancestor.Parent
            }

            return $true
        }, $true)
    )

    if ($Candidates.Count -eq 0) {
        $ScopeDescription = if ($Recurse) { 'the document' } else { 'the top level of the document' }
        throw "Function '$Name' was not found in $ScopeDescription."
    }

    if ($Candidates.Count -gt 1) {
        $Locations = $Candidates | ForEach-Object {
            "$($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber)"
        }
        throw "Function '$Name' is ambiguous. Matches were found at $($Locations -join ', ')."
    }

    $ReplacementTokens = $null
    $ReplacementErrors = $null
    $ReplacementAst = [Parser]::ParseInput(
        $Replacement,
        [ref] $ReplacementTokens,
        [ref] $ReplacementErrors
    )
    if ($ReplacementErrors.Count -gt 0) {
        throw "Replacement text contains $($ReplacementErrors.Count) parse error(s): $($ReplacementErrors[0].Message)"
    }

    $ReplacementStatements = @($ReplacementAst.EndBlock.Statements)
    if ($ReplacementAst.UsingStatements.Count -gt 0 -or
        $ReplacementStatements.Count -ne 1 -or
        -not ($ReplacementStatements[0] -is [FunctionDefinitionAst])
    ) {
        throw 'Replacement must contain exactly one complete function definition.'
    }

    $Target = $Candidates[0]
    $StartOffset = $Target.Extent.StartOffset
    $IncludedHelp = $false
    if (-not $ExcludeHelp) {
        $Tokens = $Document.Tokens
        if ($null -eq $Tokens) {
            $Tokens = $null
            $TokenErrors = $null
            [void] [Parser]::ParseInput(
                $Document.OriginalText,
                [ref] $Tokens,
                [ref] $TokenErrors
            )
        }

        $CommentGroup = [List[Token]]::new()
        $Boundary = $Target.Extent.StartOffset
        foreach ($CommentToken in ($Tokens |
                Where-Object {
                    $_.Kind -eq [TokenKind]::Comment -and
                    $_.Extent.EndOffset -le $Boundary
                } |
                Sort-Object { $_.Extent.StartOffset } -Descending)) {
            $Gap = $Document.OriginalText.Substring(
                $CommentToken.Extent.EndOffset,
                $Boundary - $CommentToken.Extent.EndOffset
            )
            if (-not [string]::IsNullOrWhiteSpace($Gap)) {
                break
            }

            $CommentGroup.Insert(0, $CommentToken)
            $Boundary = $CommentToken.Extent.StartOffset
        }

        $CommentText = ($CommentGroup | ForEach-Object { $_.Text }) -join $Document.NewLineSequence
        if ($CommentText -match '(?im)^\s*#?\s*\.(SYNOPSIS|DESCRIPTION|PARAMETER|EXAMPLE|INPUTS|OUTPUTS|NOTES|LINK)\b') {
            $StartOffset = $CommentGroup[0].Extent.StartOffset
            $IncludedHelp = $true
        }
    }

    $NormalizedReplacement = $Replacement -replace "`r?`n", $Document.NewLineSequence
    return [pscustomobject] @{
        Action = 'ReplaceFunction'
        Name = $Target.Name
        ReplacementName = $ReplacementStatements[0].Name
        TargetAst = $Target
        StartOffset = $StartOffset
        EndOffset = $Target.Extent.EndOffset
        Text = $NormalizedReplacement
        Reason = "Replace function '$($Target.Name)'."
        IncludedHelp = $IncludedHelp
    }
}
