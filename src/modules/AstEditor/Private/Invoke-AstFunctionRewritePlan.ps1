<#
.SYNOPSIS
    Queues a function rewrite plan in an AstDocument.
#>
function Invoke-AstFunctionRewritePlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-AstDocumentInstance -InputObject $_ })]
        [object] $Document,

        [Parameter(Mandatory)]
        [pscustomobject] $Plan
    )

    if ($Plan.Action -ne 'ReplaceFunction') {
        throw "Unsupported function rewrite action '$($Plan.Action)'."
    }

    $Document.ReplaceRange(
        $Plan.StartOffset,
        $Plan.EndOffset,
        $Plan.Text,
        $Plan.Reason
    )
}
