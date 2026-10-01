using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Starts applying Nitpick rules to the specified script or path.

.DESCRIPTION
    Runs the selected Nitpick rules against file-backed or in-memory PowerShell source.
    Ordinary lint behavior is unchanged unless Fix is specified.

    Fix is reserved for Nitpick's preview-first autocorrection workflow. Until that
    workflow is implemented, Fix does not change files or alter lint results.

.PARAMETER Fix
    Requests Nitpick's autocorrection workflow. Autocorrection is based on one immutable
    source snapshot per target, and file writes require a separate explicit apply step.

    This parameter is currently reserved and does not change files or lint results.
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

        [switch] $NoSummary,
        [switch] $Fix
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
                $TargetPath = if ($PSCmdlet.ParameterSetName -eq 'Path') {
                    $Ast.Extent.File
                } else {
                    $null
                }

                if (-not $Rule.AppliesToPath($TargetPath)) {
                    Write-Verbose "Rule '$($Rule.Name)' does not apply to path '$TargetPath'."
                    continue
                }

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
                Write-Host ""  # Line buffer. Host based to avoid polluting output.
                Write-Output $Summary.ToString()
            }
        }

        if ($ThresholdFindingCount -gt 0) {
            Write-Error "Encountered $ThresholdFindingCount findings at or above the '$ErrorOn' severity threshold."
            return
        }
    }
}
