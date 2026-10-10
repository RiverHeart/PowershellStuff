<#
.SYNOPSIS
    Imports a PowerShell file as a ScriptBlock AST.

.DESCRIPTION
    Imports a PowerShell file as a ScriptBlock AST.

.EXAMPLE
    Import-ScriptBlockAst -FilePath .\Public\DSL\Styling\Resources.ps1
#>
function Import-ScriptBlockAst {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.ScriptBlockAst])]
    param(
        [Parameter(Mandatory,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string] $FilePath
    )

    process {
        $ResolvedFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)
        $null = $tokens = $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($ResolvedFilePath, [ref] $tokens, [ref] $errors)
    }
}
