using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Resolves the nearest WPF control command at the cursor location.

.DESCRIPTION
    Finds command nodes in the cursor path and returns the innermost command
    that owns the scriptblock containing the cursor and maps to a known WPF
    control type.
#>
function Resolve-WPFControlCommandAstAtCursor {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.CommandAst])]
    param(
        [Parameter(Mandatory)]
        [Ast] $Ast,

        [Parameter(Mandatory)]
        [int] $CursorOffset
    )

    $MaxOffset = [Math]::Max(0, $Ast.Extent.EndOffset)
    $OffsetCandidates = [System.Collections.Generic.List[int]]::new()
    [void] $OffsetCandidates.Add([Math]::Max(0, [Math]::Min($CursorOffset, $MaxOffset)))

    if ($CursorOffset -gt 0) {
        $PreviousOffset = [Math]::Max(0, [Math]::Min($CursorOffset - 1, $MaxOffset))
        if ($PreviousOffset -ne $OffsetCandidates[0]) {
            [void] $OffsetCandidates.Add($PreviousOffset)
        }
    }

    $TypeResolutionCache = @{}

    foreach ($EffectiveOffset in $OffsetCandidates) {
        try {
            $CursorPathCommandNodes = Find-AstNode -Ast $Ast -Type CommandAst -All -Recurse -ContainsCursor -CursorOffset $EffectiveOffset
        } catch {
            Write-Debug "Failed to resolve command path at cursor offset ${EffectiveOffset}: $($_.Exception.Message)"
            continue
        }

        if (-not $CursorPathCommandNodes) {
            continue
        }

        $Candidates = foreach ($PathNode in @($CursorPathCommandNodes)) {
            $CommandName = $PathNode.GetCommandName()
            if ([string]::IsNullOrWhiteSpace($CommandName)) {
                continue
            }

            $ScopeScriptBlockExpression = @($PathNode.CommandElements | Where-Object {
                    $_ -is [ScriptBlockExpressionAst]
                }) | Select-Object -Last 1

            if (-not $ScopeScriptBlockExpression) {
                continue
            }

            $ScopeScriptBlock = $ScopeScriptBlockExpression.ScriptBlock
            if (-not $ScopeScriptBlock) {
                continue
            }

            if (
                $EffectiveOffset -lt $ScopeScriptBlock.Extent.StartOffset -or
                $EffectiveOffset -gt $ScopeScriptBlock.Extent.EndOffset
            ) {
                continue
            }

            $ControlName = if ($CommandName -ieq 'App') { 'Window' } else { $CommandName }

            if (-not $TypeResolutionCache.ContainsKey($ControlName)) {
                $TypeResolutionCache[$ControlName] = @(Get-WPFTypeInfo -Name $ControlName)
            }

            if ($TypeResolutionCache[$ControlName].Count -eq 0) {
                continue
            }

            [pscustomobject] @{
                Ast = $PathNode
                Span = $PathNode.Extent.EndOffset - $PathNode.Extent.StartOffset
                StartOffset = $PathNode.Extent.StartOffset
            }
        }

        $NearestCandidate = @($Candidates | Sort-Object -Property @(
                @{ Expression = { $_.Span }; Ascending = $true },
                @{ Expression = { $_.StartOffset }; Ascending = $false }
            )) | Select-Object -First 1

        if ($NearestCandidate) {
            return $NearestCandidate.Ast
        }
    }
}
