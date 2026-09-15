<#
.SYNOPSIS
    Queues replacement of one function in an AstDocument.
#>
function Set-AstFunction {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Replacement,

        [switch] $Recurse,

        [switch] $ExcludeHelp
    )

    $Plan = New-AstFunctionRewritePlan @PSBoundParameters
    Invoke-AstFunctionRewritePlan -Document $Document -Plan $Plan
    return $Plan
}
