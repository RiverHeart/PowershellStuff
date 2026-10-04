using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Starts applying Nitpick rules to the specified script or path.

.DESCRIPTION
    Runs the selected Nitpick rules against file-backed or in-memory PowerShell source.
    Ordinary lint behavior is unchanged unless Fix is specified. Fix applies safe,
    validated corrections to file-backed targets using transactional AstEditor saves.
    In-memory inputs return rendered text without writing.

.PARAMETER Fix
    Applies safe corrections against one immutable source snapshot per file. Use Preview
    or WhatIf to inspect the transaction without modifying files. In-memory inputs return
    rendered text in object output.

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
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='Path')]
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
                    if ($Fix) {
                        $_
                    } else {
                        Import-ScriptBlockAst $_.FullName
                    }
                }
        } else {
            $Script
        }

        foreach ($Target in $Asts) {
            $Document = $null
            $Ast = $Target
            if ($Fix) {
                try {
                    $Document = if ($PSCmdlet.ParameterSetName -eq 'Path') {
                        New-AstDocument -Path $Target.FullName
                    } else {
                        New-AstDocument -InputObject $Script
                    }
                } catch [System.IO.IOException], [System.IO.InvalidDataException], [UnauthorizedAccessException] {
                    $Summary.TargetCount++
                    $Summary.FailedTargetCount++
                    $ReadFailure = [pscustomobject]@{
                        PSTypeName = 'Nitpick.CorrectionPreviewResult'
                        Path = $Target.FullName
                        WriteStatus = 'FailedRead'
                        OriginalFingerprint = $null
                        Document = $null
                        WriteResult = $null
                        WasWritten = $false
                        WasReanalyzed = $false
                        OriginalFindings = @()
                        FinalFindings = @()
                        CandidateFindings = @()
                        RemainingFindings = @()
                        AcceptedCorrections = @()
                        FixedCorrections = @()
                        FixedFindings = @()
                        SkippedFindings = @()
                        ConflictedFindings = @()
                        FailedValidationFindings = @()
                        SkippedCorrections = @()
                        Conflicts = @()
                        ParseErrors = @()
                        CandidateText = $null
                        RenderedText = $null
                        Diff = $null
                        ErrorRecord = $_
                    }
                    if ($Output -eq 'Object') {
                        Write-Output $ReadFailure
                    } else {
                        Write-Output "Corrections (FailedRead): $($ReadFailure.Path)"
                    }
                    $PSCmdlet.WriteError($ReadFailure.ErrorRecord)
                    continue
                }
                $Ast = $Document.Ast
            }
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
                    Document = $Document
                    Finding = $TargetFindings.ToArray()
                    Rule = $ApplicableRules.ToArray()
                }
                if ($Ast.Extent.File) {
                    $ResolveParameters.Path = $Ast.Extent.File
                }

                $CorrectionPreview = Resolve-NitpickCorrection @ResolveParameters
                if (-not $CorrectionPreview.WasReanalyzed) {
                    $CorrectionPreview.FinalFindings = $TargetFindings.ToArray()
                }
                if ($CorrectionPreview.AcceptedCorrections.Count -gt 0) {
                    if (-not $Document.IsFileBacked) {
                        $CorrectionPreview.WriteStatus = 'InMemory'
                    } elseif (-not $Preview) {
                        if ($PSCmdlet.ShouldProcess($Document.Path, 'Apply Nitpick corrections')) {
                            $WriteResult = Save-AstDocument `
                                -Document $Document `
                                -Confirm:$false `
                                -WhatIf:$false
                            $CorrectionPreview.WriteResult = $WriteResult
                            $CorrectionPreview.ErrorRecord = $WriteResult.ErrorRecord
                            $CorrectionPreview.WriteStatus = $WriteResult.WriteStatus
                            $CorrectionPreview.WasWritten = $WriteResult.WasWritten
                            if ($WriteResult.WasWritten) {
                                $CorrectionPreview.FixedCorrections = $CorrectionPreview.AcceptedCorrections
                            } else {
                                $CorrectionPreview.SkippedCorrections = @($CorrectionPreview.SkippedCorrections) + @(
                                    foreach ($Correction in $CorrectionPreview.AcceptedCorrections) {
                                        [pscustomobject]@{
                                            Correction = $Correction
                                            Reason = "Commit failed ($($WriteResult.WriteStatus)): $($WriteResult.ErrorRecord.Exception.Message)"
                                        }
                                    }
                                )
                                $CorrectionPreview.FinalFindings = $TargetFindings.ToArray()
                                $CorrectionPreview.RemainingFindings = $TargetFindings.ToArray()
                                $CorrectionPreview.RenderedText = $Document.OriginalText
                                $CorrectionPreview.WasReanalyzed = $false
                            }
                        } else {
                            $CorrectionPreview.WriteStatus = if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' }
                            if (-not $WhatIfPreference) {
                                $CorrectionPreview.FinalFindings = $TargetFindings.ToArray()
                                $CorrectionPreview.RemainingFindings = $TargetFindings.ToArray()
                                $CorrectionPreview.RenderedText = $Document.OriginalText
                                $CorrectionPreview.WasReanalyzed = $false
                            }
                        }
                    }
                }
                $FinalFindings = if ($CorrectionPreview.WasReanalyzed) {
                    $CorrectionPreview.FinalFindings
                } else {
                    $TargetFindings.ToArray()
                }
                $SkippedEdits = @($CorrectionPreview.SkippedCorrections.Correction)
                $ConflictingEdits = @(
                    $CorrectionPreview.Conflicts.ExistingCorrection
                    $CorrectionPreview.Conflicts.IncomingCorrection
                )
                $FixedFindings = @($TargetFindings | Where-Object {
                    $Committed = @($_.Corrections | Where-Object {
                        $_ -in $CorrectionPreview.FixedCorrections
                    })
                    $Committed.Count -gt 0
                })
                $SkippedFindings = @($TargetFindings | Where-Object {
                    @($_.Corrections | Where-Object { $_ -in $SkippedEdits }).Count -gt 0
                })
                $ConflictedFindings = @($TargetFindings | Where-Object {
                    @($_.Corrections | Where-Object { $_ -in $ConflictingEdits }).Count -gt 0
                })
                $FailedValidationFindings = if ($CorrectionPreview.WriteStatus -eq 'FailedValidation') {
                    $TargetFindings.ToArray()
                } else {
                    @()
                }
                $CorrectionPreview | Add-Member -Force -NotePropertyMembers @{
                    FixedFindings = $FixedFindings
                    SkippedFindings = $SkippedFindings
                    ConflictedFindings = $ConflictedFindings
                    FailedValidationFindings = @($FailedValidationFindings)
                }
                $Summary.FixedFindingCount += $FixedFindings.Count
                $Summary.SkippedCorrectionCount += $CorrectionPreview.SkippedCorrections.Count
                if ($CorrectionPreview.Conflicts.Count -gt 0) {
                    $Summary.ConflictedTargetCount++
                }
                if ($CorrectionPreview.WriteStatus -in 'FailedValidation', 'FailedWrite', 'StaleSource', 'StaleTarget', 'InvalidTarget') {
                    $Summary.FailedTargetCount++
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
                Write-Output "Corrections ($($CorrectionPreview.WriteStatus)):`n"
                Write-Output $CorrectionPreview.Diff
                Write-Output (
                    "`n{0} fixed, {1} accepted, {2} skipped; write status: {3}." -f
                    $CorrectionPreview.FixedCorrections.Count,
                    $CorrectionPreview.AcceptedCorrections.Count,
                    $CorrectionPreview.SkippedCorrections.Count,
                    $CorrectionPreview.WriteStatus
                )
            }

            if ($CorrectionPreview -and $CorrectionPreview.WriteResult -and
                $CorrectionPreview.WriteResult.ErrorRecord
            ) {
                $PSCmdlet.WriteError($CorrectionPreview.WriteResult.ErrorRecord)
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
