using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Starts applying Nitpick rules to the specified script or path.
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
        Find-Nitpick | ForEach-Object {
            Register-Nitpick -Command $_
        }

        foreach ($RuleModuleEntry in $RuleModule) {
            Register-Nitpick -Module $RuleModuleEntry
        }

        # TODO: Figure out how to register rules from a specified path
        # foreach ($RulePathEntry in $RulePath) {
        #     . $RulePathEntry
        # }

        $Rules = Get-Nitpick | Where-Object {
            ($null -eq $IncludeRule -or $_ -in $IncludeRule) -and
            ($null -eq $ExcludeRule -or $_ -notin $ExcludeRule)
        }

        if ($null -eq $Rules) {
            # TODO: Be more detailed about where we searched for rules
            Write-Warning "No rules found to apply."
            return
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
            foreach ($Rule in $Rules) {
                $Rule.Invoke($Ast)
            }
        }
    }
}
