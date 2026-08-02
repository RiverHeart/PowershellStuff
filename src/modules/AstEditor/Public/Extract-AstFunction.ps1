<#
.SYNOPSIS
    Queues removal of one function and returns its source text.

.DESCRIPTION
    Structurally selects one top-level function by name, captures its complete source
    text, and queues its removal from the document. Contiguous comment-based help
    immediately above the function is included unless ExcludeHelp is specified.
#>
function Extract-AstFunction {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-AstDocumentInstance -InputObject $_ })]
        [object] $Document,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [switch] $ExcludeHelp
    )

    $Candidates = @(
        $Document.Ast.FindAll({
            param($Node)

            if ($Node -isnot [FunctionDefinitionAst] -or $Node.Name -ine $Name) {
                return $false
            }

            $Ancestor = $Node.Parent
            while ($null -ne $Ancestor) {
                if ($Ancestor -is [FunctionDefinitionAst] -or $Ancestor -is [TypeDefinitionAst]) {
                    return $false
                }
                $Ancestor = $Ancestor.Parent
            }

            return $true
        }, $true)
    )

    if ($Candidates.Count -eq 0) {
        throw "Function '$Name' was not found in the top level of the document."
    }

    if ($Candidates.Count -gt 1) {
        $Locations = $Candidates | ForEach-Object {
            "$($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber)"
        }
        throw "Function '$Name' is ambiguous. Matches were found at $($Locations -join ', ')."
    }

    $Target = $Candidates[0]
    $StartOffset = $Target.Extent.StartOffset
    $IncludedHelp = $false
    if (-not $ExcludeHelp) {
        $CommentGroup = [List[Token]]::new()
        $Boundary = $StartOffset
        foreach (
            $CommentToken in ($Document.Tokens |
                Where-Object {
                    $_.Kind -eq [TokenKind]::Comment -and
                    $_.Extent.EndOffset -le $Boundary
                } |
                Sort-Object { $_.Extent.StartOffset } -Descending)
        ) {
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

    $EndOffset = $Target.Extent.EndOffset
    $ExtractedText = $Document.OriginalText.Substring(
        $StartOffset,
        $EndOffset - $StartOffset
    )
    $Document.ReplaceRange(
        $StartOffset,
        $EndOffset,
        '',
        "Extract function '$($Target.Name)'."
    )

    return [pscustomobject] @{
        Action = 'ExtractFunction'
        Name = $Target.Name
        TargetAst = $Target
        StartOffset = $StartOffset
        EndOffset = $EndOffset
        Text = $ExtractedText
        IncludedHelp = $IncludedHelp
    }
}
