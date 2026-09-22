using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Powershell first replacement for PSScriptAnalyzer
#>
function Start-Nitpicking {
    [CmdletBinding(DefaultParameterSetName='Path')]
    [Alias('nitpick', 'np')]
    param(
        [Parameter(Mandatory,ParameterSetName='Path',ValueFromPipeline)]
        [string] $Path,

        [Parameter(Mandatory,ParameterSetName='Script')]
        [ScriptBlockAstTransform()]
        [ScriptBlockAst] $Script,

        [string[]] $CustomRulePath,

        [string[]] $IncludeRule,
        [string[]] $ExcludeRule,

        [string[]] $IncludePath,
        [string[]] $ExcludePath
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            #Get-ChildItem -Path $Path -Recurse | Import-ScriptBlockAst
        } else {
            #
        }

        Write-Host "Foo"
    }
}
