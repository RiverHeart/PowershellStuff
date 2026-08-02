<#
.SYNOPSIS
    Applies a Loaded-handler rewrite plan to an AstDocument.

.DESCRIPTION
    Converts the rewrite plan into the existing text-edit primitives.
    The emitter stays intentionally small so the semantic decision is explicit.
#>
function Invoke-WpfDslLoadedHandlerRewritePlan {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-AstDocumentInstance -InputObject $_ })]
        [object] $Document,

        [Parameter(Mandatory)]
        [pscustomobject] $Plan
    )

    switch ($Plan.Action) {
        'InsertAfterExisting' {
            $Document.Append($Plan.TargetAst, $Plan.Text, $Plan.Reason)
            return $true
        }

        'AppendToExistingBody' {
            $ExistingHandlerScriptBlockExpression = $Plan.TargetAst.CommandElements | Where-Object {
                $_ -is [ScriptBlockExpressionAst]
            } | Select-Object -First 1

            if (-not $ExistingHandlerScriptBlockExpression) {
                throw "Loaded handler was detected but no scriptblock body was found."
            }

            $Document.InsertBeforeScriptBlockClose($ExistingHandlerScriptBlockExpression.ScriptBlock, $Plan.Text, $Plan.Reason)
            return $true
        }

        'InsertMissingHandler' {
            $Document.InsertBeforeScriptBlockClose($Plan.TargetAst, $Plan.Text, $Plan.Reason)
            return $true
        }

        default {
            return $false
        }
    }
}
