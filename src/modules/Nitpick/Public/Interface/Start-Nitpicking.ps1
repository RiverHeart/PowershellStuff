using namespace System
using namespace System.Diagnostics
using namespace System.IO
using namespace System.Security
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Starts applying Nitpick rules to the specified script or path.

.DESCRIPTION
    Runs the selected Nitpick rules against file-backed or in-memory PowerShell source.
    Ordinary lint behavior is unchanged when FixMode is Off. FixMode Apply applies safe,
    validated corrections to file-backed targets using transactional AstEditor saves.
    In-memory inputs return candidate text without writing. Correction output separates
    stable proposal facts, application outcomes, and effective reporting. PowerShell
    parser errors are reported as Error findings. Rule selection must succeed before
    any targets are read.
    Native findings and corrections carry the executing rule's qualified RuleId.
    Parser findings use Nitpick/PowerShellParseError without introducing a selectable rule.

.PARAMETER IncludeRule
    Selects qualified rule IDs (Namespace/Name), such as Nitpick/UseIsNotOperator or
    WPF/AvoidBlockingUI, not command names such as Test-UseIsNotOperator and not bare
    local names. Matching is case-insensitive and supports wildcards. Every literal
    selector must match a discovered or registered rule before exclusions and
    editor-mode filtering. Unmatched wildcard selectors are allowed, provided at
    least one eligible rule remains.

.PARAMETER Module
    Module names or literal paths to acquire as additive rule packages, alongside the
    built-in package and any explicit registrations. Package manifests may declare
    rule commands and supporting modules; supporting modules use the declared owner's
    namespace even when acquired directly. Does not register acquired rules.

.PARAMETER ExcludeDefaults
    Omits the built-in Nitpick package, including when Module is also omitted (in
    which case no rules are discovered; registered rules may still apply).

.PARAMETER Path
    A file, directory, or wildcard path. Literal paths must exist. File targets are
    resolved across all piped paths before analysis or fixing. Empty wildcard matches
    are allowed, but the complete invocation must select at least one file.

.PARAMETER IncludePath
    Filters resolved file targets by full path, before ExcludePath is applied.
    Literal selectors must match a file's full path; wildcard selectors may match
    nothing. Validation is across the invocation and precedes analysis or fixing.

.PARAMETER ExcludePath
    Excludes matching full paths. Unmatched exclusions are allowed, but at least one
    file must remain after filtering. Path filters do not apply to Script inputs.

.PARAMETER ExcludeRule
    Excludes matching rule IDs. Unmatched exclusions are allowed. If no eligible
    rules remain after exclusions and editor-mode filtering, execution terminates.

.PARAMETER FixMode
    Specifies the mode for applying corrections.
    'Off'     - Do not apply any corrections.
    'Preview' - Preview safe corrections without modifying files.
    'Guided'  - Interactive correction process (not yet implemented).
    'Apply'   - Apply safe corrections.

    NOTE: Applying against in-memory inputs returns candidate text
    in object output under `Report.EffectiveText`.

.PARAMETER EditorMode
    Runs only rules whose EditorEnabled metadata is true.

.EXAMPLE
    Run Start-Nitpicking against a script with the specified rule.

    Start-Nitpicking `
        -Script 'param([Parameter(Mandatory=$true)] [string] $Name)' `
        -IncludeRule Nitpick/AvoidParameterAttributeBool

.EXAMPLE
    Run Start-Nitpicking against a script and apply safe corrections.

    Start-Nitpicking `
        -Script 'param([Parameter(Mandatory=$true)] [string] $Name)' `
        -IncludeRule Nitpick/AvoidParameterAttributeBool `
        -FixMode Apply

.EXAMPLE
    Run Start-Nitpicking against a script and preview safe corrections.

    Start-Nitpicking `
        -Script 'param([Parameter(Mandatory=$true)] [string] $Name)' `
        -IncludeRule Nitpick/AvoidParameterAttributeBool `
        -FixMode Preview

.EXAMPLE
    Run Start-Nitpicking using rules sourced from a module against
    a specified path with preview mode for corrections.

    Start-Nitpicking -Module WPF -Path src/modules/WPF/Public/DSL -FixMode Preview
#>
function Start-Nitpicking {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='Path')]
    [Alias('nitpick', 'np')]
    [OutputType([string])]
    [OutputType('NitpickFinding', 'NitpickSummary', 'NitpickCorrectionResult')]
    param(
        [Parameter(Mandatory,ParameterSetName='Path',ValueFromPipeline)]
        [string] $Path,

        [string] $Filter = '*.ps1',

        [Parameter(Mandatory,ParameterSetName='Script')]
        [ScriptBlockAstTransform()]
        [ScriptBlockAst] $Script,

        [string[]] $Module,

        [string[]] $IncludeRule,
        [string[]] $ExcludeRule,

        [string[]] $IncludePath,
        [string[]] $ExcludePath,

        [ValidateSet('Error', 'Warning', 'Information')]
        [string] $ErrorOn = 'Error',

        [ValidateSet('Text', 'Object')]
        [string] $Output = 'Text',

        # TODO: Implement guided mode as an interactive correction process.
        [ValidateSet('Off', 'Preview', 'Guided', 'Apply')]
        [string] $FixMode = 'Off',

        [switch] $ExcludeDefaults,
        [switch] $EditorMode,
        [switch] $NoSummary
    )

    # MARK: BEGIN BLK
    begin {
        [object[]] $Rules = Resolve-NitpickEffectiveRuleSet `
            -Module $Module `
            -IncludeRule $IncludeRule `
            -ExcludeRule $ExcludeRule `
            -ExcludeDefaults:$ExcludeDefaults `
            -EditorMode:$EditorMode

        $Summary = [NitpickSummary]::new()
        $Summary.RuleCount = $Rules.Count
        $Stopwatch = [Stopwatch]::StartNew()
        $SeverityRank = @{
            Information = 0
            Warning = 1
            Error = 2
        }
        $ThresholdFindingCount = 0
        $ResolvedTargets = [List[object]]::new()
        $CandidatePaths = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    }

    # MARK: PROCESS BLK
    process {
        $Targets = if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $Roots = if ([WildcardPattern]::ContainsWildcardCharacters($Path)) {
                Get-Item -Path $Path -ErrorAction Stop
            } else {
                Get-Item -LiteralPath $Path -ErrorAction Stop
            }

            $Files = @(
                foreach ($Root in $Roots) {
                    if ($Root.PSIsContainer) {
                        Get-ChildItem -LiteralPath $Root.FullName -File -Recurse -Filter $Filter -ErrorAction Stop
                    } elseif ($Root -is [FileInfo] -and $Root.Name -like $Filter) {
                        $Root
                    }
                }
            )

            foreach ($File in $Files) {
                [void] $CandidatePaths.Add($File.FullName)
            }

            $Files | Where-NitpickIncluded `
                -PropertyPath FullName `
                -Include $IncludePath `
                -Exclude $ExcludePath `
                -Wildcard
        } else {
            $Script
        }

        foreach ($Target in $Targets) {
            $ResolvedTargets.Add($Target)
        }
    }

    # MARK: END BLK
    end {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $UnmatchedPaths = @(
                foreach ($Selector in $IncludePath) {
                    if (-not [WildcardPattern]::ContainsWildcardCharacters($Selector) -and
                        -not $CandidatePaths.Contains($Selector)) {
                        $Selector
                    }
                }
            )

            if ($UnmatchedPaths.Count -gt 0) {
                throw "No file targets match the literal IncludePath selector(s): $($UnmatchedPaths -join ', '). Use full file paths or wildcard filters."
            }

            if ($ResolvedTargets.Count -eq 0) {
                throw 'No file targets remain after resolving paths and applying Filter, IncludePath, and ExcludePath.'
            }
        }

        # MARK: NITPICK

        # Text blocks are separated with host-only blank lines to keep the pipeline clean.
        $HasWrittenTextBlock = $false
        foreach ($Target in $ResolvedTargets) {
            $Document = $null
            $TargetPath = if ($PSCmdlet.ParameterSetName -eq 'Path') {
                $Target.FullName
            } else {
                '<ScriptBlock>'
            }

            try {
                $Document = if ($PSCmdlet.ParameterSetName -eq 'Path') {
                    New-AstDocument -Path $Target.FullName
                } else {
                    New-AstDocument -InputObject $Target
                }

                # WARNING: Keep original extent context for rules; reparsing memory input resets it.
                $Ast = if ($PSCmdlet.ParameterSetName -eq 'Script' -and $FixMode -eq 'Off') {
                    $Target
                } else {
                    $Document.Ast
                }
                $ParseErrors = $Document.ParseErrors
            } catch [IOException], [InvalidDataException], [SecurityException], [ItemNotFoundException], [UnauthorizedAccessException] {
                $Summary.TargetCount++
                $Summary.FailedTargetCount++

                if ($FixMode -ne 'Off') {
                    $ReadFailure = New-NitpickCorrectionResult `
                        -Path $TargetPath `
                        -Application @{ Status = 'FailedRead'; ErrorRecord = $_ }

                    if ($Output -eq 'Object') {
                        Write-Output $ReadFailure
                    } else {
                        if ($HasWrittenTextBlock) { Write-Host '' }
                        Write-Output ("{0}`n  Corrections not attempted: the target could not be read." -f
                            $ReadFailure.Path)
                        $HasWrittenTextBlock = $true
                    }
                }

                $PSCmdlet.WriteError($_)
                continue
            }

            $Summary.TargetCount++
            $TargetFindings = [List[object]]::new()
            foreach ($ParseError in $ParseErrors) {
                $ParserFinding = New-NitpickFinding `
                    -RuleName 'PowerShellParseError' `
                    -Message $ParseError.Message `
                    -ViolationExtent $ParseError.Extent `
                    -Severity Error `
                    -RuleSuppressionID 'PowerShellParseError' `
                    -ScriptPath $TargetPath `
                    -Explanation 'The PowerShell parser could not parse this source.' `
                    -OutputAs NitpickFinding

                $ParserFinding.RuleId = 'Nitpick/PowerShellParseError'
                $TargetFindings.Add($ParserFinding)
            }

            $ApplicableRules = [List[NitpickRule]]::new()
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

            $CorrectionResult = $null
            $FinalFindings = $TargetFindings.ToArray()
            if ($FixMode -ne 'Off') {
                $CorrectionResult = Resolve-NitpickTargetCorrection `
                    -Preview:($FixMode -eq 'Preview') `
                    -Document $Document `
                    -Finding $TargetFindings.ToArray() `
                    -Rule $ApplicableRules.ToArray() `
                    -Ast $Ast

                $FinalFindings = $CorrectionResult.Report.EffectiveFindings
                $Summary.FindingsWithCommittedCorrectionsCount +=
                    $CorrectionResult.Report.FindingsWithCommittedCorrections.Count

                $Summary.SkippedCorrectionCount += $CorrectionResult.Proposal.SkippedCorrections.Count

                if ($CorrectionResult.Proposal.Conflicts.Count -gt 0) {
                    $Summary.ConflictedTargetCount++
                }

                if ($CorrectionResult.Proposal.Status -eq 'FailedValidation' -or
                    $CorrectionResult.Application.Status -in
                        'FailedValidation', 'FailedWrite', 'StaleSource', 'StaleTarget', 'InvalidTarget') {
                    $Summary.FailedTargetCount++
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

            if ($Output -eq 'Object' -and $CorrectionResult) {
                Write-Output $CorrectionResult
            }

            if ($Output -eq 'Text') {
                [array] $SortedFindings = $FinalFindings | Sort-Object `
                    -Property @{ Expression = { $_.ViolationExtent.StartLineNumber } },
                              @{ Expression = { $_.ViolationExtent.StartColumnNumber } }

                $TargetText = Format-NitpickText -Ast $Ast -Finding $SortedFindings -CorrectionResult $CorrectionResult

                if ($TargetText) {
                    if ($HasWrittenTextBlock) { Write-Host '' }
                    Write-Output $TargetText
                    $HasWrittenTextBlock = $true
                }
            }

            if ($CorrectionResult -and $CorrectionResult.Application.ErrorRecord) {
                $PSCmdlet.WriteError($CorrectionResult.Application.ErrorRecord)
            }
        }
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
