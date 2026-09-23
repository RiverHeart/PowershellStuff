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

        [string] $Filter = '*.ps1',

        [Parameter(Mandatory,ParameterSetName='Script')]
        [ScriptBlockAstTransform()]
        [ScriptBlockAst] $Script,

        [string[]] $RulePath,
        [string[]] $RuleModule,

        [string[]] $IncludeRule,
        [string[]] $ExcludeRule,

        [string[]] $IncludePath,
        [string[]] $ExcludePath
    )

    begin {
        foreach ($RuleModuleEntry in $RuleModule) {
            Register-Nitpick -Module $RuleModuleEntry
        }

        foreach ($RulePathEntry in $RulePath) {
            . $RulePathEntry
        }

        $Rules = Get-Nitpick | Where-Object {
            ($null -eq $IncludeRule -or $_ -in $IncludeRule) -and
            ($null -eq $ExcludeRule -or $_ -notin $ExcludeRule)
        }
    }

    process {
        $Asts = if ($PSCmdlet.ParameterSetName -eq 'Path') {
            Get-ChildItem -Path $Path -Recurse -Filter $Filter |
                ForEach-Object {
                    $FilePath = $_.FullName
                    $FilePath |
                    Where-Object {
                        ($null -eq $IncludePath -or $_ -in $IncludePath) -and
                        ($null -eq $ExcludePath -or $_ -notin $ExcludePath)
                    } |
                    Import-ScriptBlockAst $FilePath
                }
        } else {
            $Script
        }

        foreach ($Ast in $Asts) {
            Invoke-Nitpick -Ast $Ast -Rules $Rules
        }
    }
}
