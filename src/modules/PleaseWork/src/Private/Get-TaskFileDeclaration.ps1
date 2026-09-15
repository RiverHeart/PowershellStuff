<#
.SYNOPSIS
    Reads ordered TaskFile declaration metadata without invoking the TaskFile.
#>
function Get-TaskFileDeclaration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $TaskFileScript = [scriptblock]::Create([System.IO.File]::ReadAllText($ResolvedPath))
    return Get-TaskDeclaration -ScriptBlock $TaskFileScript
}
