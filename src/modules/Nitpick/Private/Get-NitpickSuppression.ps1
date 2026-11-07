using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Reads target, physical-line, and ordered regional directives from snapshot tokens.
#>
function Get-NitpickSuppression {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document
    )

    $Selectors = [List[string]]::new()
    $LineSelectors = @{}
    $Regions = [List[object]]::new()
    $Diagnostics = [List[object]]::new()
    $Tokens = [List[Token]]::new()
    $Pending = [Queue[Token]]::new()

    foreach ($Token in $Document.Tokens) {
        $Pending.Enqueue($Token)
    }

    while ($Pending.Count -gt 0) {
        $Token = $Pending.Dequeue()
        $Tokens.Add($Token)

        if ($Token -is [StringExpandableToken]) {
            foreach ($NestedToken in $Token.NestedTokens) {
                $Pending.Enqueue($NestedToken)
            }
        }
    }

    $InPreamble = $true
    foreach ($Token in ($Tokens | Sort-Object { $_.Extent.StartOffset })) {
        # Only the submitted ScriptBlock's own opening brace is a target boundary.
        if ($Document.IsFragment -and $Document.Ast -is [ScriptBlockAst] -and
            $Token.Kind -eq [TokenKind]::LCurly -and
            $Token.Extent.StartOffset -eq $Document.Ast.Extent.StartOffset) {
            continue
        }

        if ($Token.Kind -in 'NewLine', 'EndOfInput') {
            continue
        }

        if ($Token.Kind -ne 'Comment') {
            $InPreamble = $false
            continue
        }

        if ($Token.Text -notmatch '^#\s*nitpick(?:\s|$)') {
            continue
        }

        $Problem = $null
        $DirectiveSelectors = [List[string]]::new()
        if ($Token.Text -notmatch '^#\s*nitpick\s+(\S+)(?:\s+(.*))?$') {
            $Problem = 'Expected an action and at least one qualified rule selector.'
        } else {
            $Action = $Matches[1]
            [string] $Arguments = $Matches[2]

            $IsStandalone = $Token.Extent.StartScriptPosition.Line.Substring(
                0, $Token.Extent.StartColumnNumber - 1
            ) -notmatch '\S'

            if ($Action -notin 'disable-target', 'disable-line', 'disable-next-line', 'disable', 'enable') {
                $Problem = "Unsupported action '$Action'. Supported actions are disable-target, disable-line, disable-next-line, disable, and enable."
            } elseif (
                $Action -eq 'disable-target' -and (-not $InPreamble -or -not $IsStandalone)
            ) {
                $Problem = 'disable-target must be a standalone comment in the leading comment/whitespace preamble.'
            } elseif ($Action -ne 'disable-line' -and -not $IsStandalone) {
                $Problem = "$Action must be a standalone comment."
            } else {
                $SelectorText = ($Arguments -split '\s+--(?:\s|$)', 2)[0].Trim()

                foreach ($Entry in ($SelectorText -split ',')) {
                    if ([string]::IsNullOrWhiteSpace($Entry)) {
                        $Problem = 'Expected a nonempty rule selector between commas.'
                        break
                    }

                    foreach ($Selector in ($Entry.Trim() -split '\s+')) {
                        if ($Selector -ne '*' -and
                            $Selector -notmatch '^[^/\s,]+/[^/\s,]+$'
                        ) {
                            $Problem = "Invalid selector '$Selector'. Use a qualified rule ID or '*'."
                            break
                        }

                        try {
                            $Pattern = [WildcardPattern]::new($Selector, [WildcardOptions]::IgnoreCase)
                            $null = $Pattern.IsMatch('')
                        } catch [WildcardPatternException] {
                            $Problem = "Invalid wildcard selector '$Selector'."
                            break
                        }

                        $DirectiveSelectors.Add($Selector)
                    }

                    if ($Problem) { break }
                }
            }
        }

        if ($Problem) {
            $Diagnostics.Add((New-NitpickFinding `
                -RuleId 'Nitpick/InvalidSuppressionDirective' `
                -Message "Invalid Nitpick suppression directive: $Problem" `
                -ViolationExtent $Token.Extent `
                -Severity Warning `
                -ScriptPath $(if ($Token.Extent.File) { $Token.Extent.File } else { '<ScriptBlock>' }) `
                -Explanation 'Malformed or unsupported suppression directives are ignored as a whole.' `
                -OutputAs NitpickFinding
            ))
        } elseif ($Action -eq 'disable-target') {
            $Selectors.AddRange($DirectiveSelectors)
        } elseif ($Action -in 'disable', 'enable') {
            $Regions.Add([pscustomobject]@{
                StartLineNumber = $Token.Extent.StartLineNumber + 1
                Disabled = $Action -eq 'disable'
                Selectors = $DirectiveSelectors.ToArray()
            })
        } else {
            $Line = $Token.Extent.StartLineNumber
            if ($Action -eq 'disable-next-line') { $Line++ }

            if (-not $LineSelectors.ContainsKey($Line)) {
                $LineSelectors[$Line] = [List[string]]::new()
            }

            $LineSelectors[$Line].AddRange($DirectiveSelectors)
        }
    }

    [pscustomobject]@{
        Selectors = $Selectors.ToArray()
        LineSelectors = $LineSelectors
        Regions = $Regions.ToArray()
        Diagnostics = $Diagnostics.ToArray()
    }
}
