using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Starts applying Nitpick rules to the specified script or path.

.DESCRIPTION
    Runs the selected Nitpick rules against file-backed or in-memory PowerShell source.
    Ordinary lint behavior is unchanged unless Fix is specified. In this phase Fix previews
    safe corrections and reanalyzes the rendered source; it never writes files.

.PARAMETER Fix
    Requests Nitpick's autocorrection workflow. In this phase, Fix previews safe corrections
    against one immutable source snapshot per target. File-backed and in-memory inputs are
    never modified.

.PARAMETER Preview
    Previews safe corrections against one immutable source snapshot per target. Final
    findings and severity counts reflect reanalysis when the rendered source parses. Use
    with Fix to explicitly request preview-only behavior; Preview without Fix is invalid.

.PARAMETER EditorMode
    Runs only rules whose EditorEnabled metadata is true.

.EXAMPLE
    Run Start-Nitpicking against a script and preview safe corrections.

    Start-Nitpicking `
        -Script 'param([Parameter(Mandatory=$true)] [string] $Name)' `
        -IncludeRule AvoidParameterAttributeBool `
        -Fix `
        -Preview
#>
function Start-Nitpicking {
    [CmdletBinding(DefaultParameterSetName='Path')]
    [Alias('nitpick', 'np')]
    [OutputType([string])]
    [OutputType('NitpickFinding', 'NitpickSummary', 'Nitpick.CorrectionPreviewResult')]
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

        [switch] $EditorMode,
        [switch] $NoSummary,
        [switch] $Fix,
        [switch] $Preview
    )

    begin {
        if ($Preview -and -not $Fix) {
            throw 'The Preview switch requires Fix.'
        }

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

        [object[]] $Rules = Get-Nitpick `
            -IncludeRule $IncludeRule `
            -ExcludeRule $ExcludeRule |
            Where-Object { -not $EditorMode -or $_.EditorEnabled }

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
            $ApplicableRules = [System.Collections.Generic.List[NitpickRule]]::new()
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

                $ApplicableRules.Add($Rule)
                foreach ($Finding in $Rule.Invoke($Ast)) {
                    $TargetFindings.Add($Finding)
                }
            }

            $FinalFindings = $TargetFindings.ToArray()
            $CorrectionPreview = $null
            if ($Fix) {
                $ResolveParameters = @{
                    Script = $Ast.Extent.Text
                    Finding = $TargetFindings.ToArray()
                    Rule = $ApplicableRules.ToArray()
                }
                if ($Ast.Extent.File) {
                    $ResolveParameters.Path = $Ast.Extent.File
                }

                $CorrectionPreview = Resolve-NitpickCorrection @ResolveParameters
                $FinalFindings = if ($CorrectionPreview.WasReanalyzed) {
                    $CorrectionPreview.FinalFindings
                } else {
                    $TargetFindings.ToArray()
                }

                Write-Verbose (
                    "Correction preview for '{0}': {1} accepted, {2} skipped." -f
                    $CorrectionPreview.Path,
                    $CorrectionPreview.AcceptedCorrections.Count,
                    $CorrectionPreview.SkippedCorrections.Count
                )
                foreach ($SkippedCorrection in $CorrectionPreview.SkippedCorrections) {
                    Write-Verbose (
                        "Skipped correction from '{0}': {1}" -f
                        $SkippedCorrection.Correction.RuleName,
                        $SkippedCorrection.Reason
                    )
                }
            }

            foreach ($Finding in $FinalFindings) {
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
                }
            }

            if ($Output -eq 'Object' -and $CorrectionPreview) {
                Write-Output $CorrectionPreview
            }

            if ($Output -eq 'Text' -and $CorrectionPreview) {
                Write-Output "Correction preview:`n"
                Write-Output $CorrectionPreview.Diff
                Write-Output (
                    "`n{0} accepted, {1} skipped; files were not changed." -f
                    $CorrectionPreview.AcceptedCorrections.Count,
                    $CorrectionPreview.SkippedCorrections.Count
                )
            }

            if ($Output -eq 'Text' -and $FinalFindings.Count -gt 0) {
                $SortedFindings = $FinalFindings | Sort-Object `
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
