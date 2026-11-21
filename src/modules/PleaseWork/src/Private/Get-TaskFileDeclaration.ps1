using namespace System.IO

<#
.SYNOPSIS
    Reads ordered TaskFile declaration metadata without invoking the TaskFile.
#>
function Get-TaskFileDeclaration {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $TaskFileScript = [scriptblock]::Create([File]::ReadAllText($ResolvedPath))
    return Get-TaskDeclaration -ScriptBlock $TaskFileScript
}
