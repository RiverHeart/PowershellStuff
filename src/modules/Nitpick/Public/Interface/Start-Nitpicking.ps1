using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Starts applying Nitpick rules to the specified script or path.
#>
function Start-Nitpicking {
    [CmdletBinding(DefaultParameterSetName='Path')]
    [Alias('nitpick', 'np')]
    [OutputType([string])]
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

        [ValidateSet('Error', 'Warning', 'Information')]
        [string] $ErrorOn = 'Error',

        [ValidateSet('Text', 'Object')]
        [string] $Output = 'Text',

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
        $SeverityRank = @{
            Information = 0
            Warning = 1
            Error = 2
        }
        $ThresholdFindingCount = 0
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
            $TargetFindings = [System.Collections.Generic.List[object]]::new()
            foreach ($Rule in $Rules) {
                foreach ($Finding in $Rule.Invoke($Ast)) {
                    $Summary.FindingCount++
                    switch ($Finding.Severity) {
                        'Error' { $Summary.ErrorCount++ }
                        'Warning' { $Summary.WarningCount++ }
                        'Information' { $Summary.InformationCount++ }
                    }
                    if ($ErrorOn -and
                        $SeverityRank.ContainsKey($Finding.Severity) -and
                        $SeverityRank[$Finding.Severity] -ge $SeverityRank[$ErrorOn]
                    ) {
                        $ThresholdFindingCount++
                    }
                    if ($Output -eq 'Object') {
                        Write-Output $Finding
                    } else {
                        $TargetFindings.Add($Finding)
                    }
                }
            }

            if ($Output -eq 'Text' -and $TargetFindings.Count -gt 0) {
                $SortedFindings = $TargetFindings | Sort-Object `
                    -Property @{ Expression = { $_.ViolationExtent.StartLineNumber } },
                              @{ Expression = { $_.ViolationExtent.StartColumnNumber } }
                ConvertTo-NitpickText -Ast $Ast -Finding $SortedFindings
            }
        }
    }

    end {
        $Stopwatch.Stop()
        $Summary.Duration = $Stopwatch.Elapsed

        if (-not $NoSummary) {
            if ($Output -eq 'Object') {
                Write-Output $Summary
            } else {
                Write-Output ''  # Line buffer for readability.
                Write-Output $Summary.ToString()
            }
        }

        if ($ThresholdFindingCount -gt 0) {
            Write-Error "Encountered $ThresholdFindingCount findings at or above the '$ErrorOn' severity threshold."
            return
        }
    }
}
