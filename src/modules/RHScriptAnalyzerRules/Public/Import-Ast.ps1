<#
.SYNOPSIS
    Imports a PowerShell file as an AST.

.DESCRIPTION
    Parses the specified file and returns the resulting AST for downstream
    analysis helpers.

.EXAMPLE
    Import-Ast -FilePath .\Public\DSL\Styling\Resources.ps1
#>
function Import-Ast {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.Ast])]
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