using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Starts applying Nitpick rules to the specified script or path.
#>
function Start-Nitpicking {
    [CmdletBinding(DefaultParameterSetName='Path')]
    [Alias('nitpick', 'np')]
    [OutputType('NitpickFinding', 'NitpickSummary')]
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
        [string[]] $ExcludePath,

        [switch] $NoSummary
    )

    begin {
        Find-Nitpick `
            -IncludeRule $IncludeRule `
            -ExcludeRule $ExcludeRule |
        Register-Nitpick

        foreach ($RuleModuleEntry in $RuleModule) {
            Register-Nitpick -Module $RuleModuleEntry
        }

        # TODO: Figure out how to register rules from a specified path
        # foreach ($RulePathEntry in $RulePath) {
        #     . $RulePathEntry
        # }

        $Rules = Get-Nitpick -IncludeRule $IncludeRule -ExcludeRule $ExcludeRule

        if (-not $Rules) {
            # TODO: Be more detailed about where we searched for rules
            Write-Warning "No rules found to apply."
        }

        $Summary = [NitpickSummary]::new()
        $Summary.RuleCount = $Rules.Count
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }

    process {
        $Asts = if ($PSCmdlet.ParameterSetName -eq 'Path') {
            Get-ChildItem -Path $Path -Recurse -Filter $Filter |
                Where-NitpickIncluded `
                    -PropertyPath FullName `
                    -Include $IncludePath `
                    -Exclude $ExcludePath `
                    -Wildcard |
                ForEach-Object {
                    Import-ScriptBlockAst $_.FullName
                }
        } else {
            $Script
        }

        foreach ($Ast in $Asts) {
            $Summary.TargetCount++
            foreach ($Rule in $Rules) {
                foreach ($Finding in @($Rule.Invoke($Ast))) {
                    $Summary.FindingCount++
                    switch ($Finding.Severity) {
                        'Error' { $Summary.ErrorCount++ }
                        'Warning' { $Summary.WarningCount++ }
                        'Information' { $Summary.InformationCount++ }
                    }
                    Write-Output $Finding
                }
            }
        }
    }

    end {
        $Stopwatch.Stop()
        $Summary.Duration = $Stopwatch.Elapsed

        if (-not $NoSummary) {
            Write-Output $Summary
        }
    }
}
