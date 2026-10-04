BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

BeforeDiscovery {
    $SeverityRanks = @{
        Information = 0
        Warning = 1
        Error = 2
    }
    $SeverityThresholdCases = foreach ($ErrorOn in 'Information', 'Warning', 'Error') {
        foreach ($FindingSeverity in 'Information', 'Warning', 'Error') {
            @{
                ErrorOn = $ErrorOn
                FindingSeverity = $FindingSeverity
                ShouldError = $SeverityRanks[$FindingSeverity] -ge $SeverityRanks[$ErrorOn]
            }
        }
    }
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Start-Nitpicking' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'filters paths using wildcard include and exclude patterns' {
        $IncludedPath = Join-Path $TestDrive 'included.ps1'
        $ExcludedPath = Join-Path $TestDrive 'excluded.ps1'
        $RuleViolation = 'param([Parameter(Mandatory=$true)] [string] $Name)'
        Set-Content -Path $IncludedPath -Value $RuleViolation
        Set-Content -Path $ExcludedPath -Value "$RuleViolation`n$RuleViolation"

        $Results = @(
            Start-Nitpicking `
                -Path $TestDrive `
                -IncludePath '*.ps1' `
                -ExcludePath '*excluded.ps1' `
                -IncludeRule AvoidParameterAttributeBool `
                -Output Object
        )

        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Findings.Count | Should -Be 1
        $Summary.TargetCount | Should -Be 1
        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 1
        $Summary.InformationCount | Should -Be 1
    }

    It 'applies rule path scopes only to file-backed targets' {
        $RuleScript = {
            [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
            param(
                [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
                [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,

                [Parameter(ParameterSetName='Details')]
                [switch] $Details
            )

            if ($Details) {
                return [pscustomobject]@{
                    Name = 'ScopedRule'
                    Source = 'Tests'
                    IncludePath = @('*.dsl.ps1')
                    ExcludePath = @('*/excluded/*')
                }
            }

            New-NitpickFinding `
                -RuleName ScopedRule `
                -Message 'Scoped rule ran' `
                -ViolationExtent $ScriptBlockAst.Extent `
                -Severity Information `
                -RuleSuppressionID ScopedRule `
                -ScriptPath $ScriptBlockAst.Extent.File `
                -Explanation 'Verifies scoped dispatch.' `
                -OutputAs NitpickFinding
        }

        $ExcludedDirectory = New-Item -Path (Join-Path $TestDrive 'excluded') -ItemType Directory
        Set-Content -Path (Join-Path $TestDrive 'included.dsl.ps1') -Value '$Included'
        Set-Content -Path (Join-Path $TestDrive 'ordinary.ps1') -Value '$Ordinary'
        Set-Content -Path (Join-Path $ExcludedDirectory 'excluded.dsl.ps1') -Value '$Excluded'
        Register-Nitpick `
            -Callable $RuleScript `
            -Name ScopedRule `
            -Source Tests

        $PathResults = @(
            Start-Nitpicking `
                -Path $TestDrive `
                -IncludeRule ScopedRule `
                -Output Object `
                -NoSummary
        )
        $ScriptResults = @(
            Start-Nitpicking `
                -Script { $Anonymous } `
                -IncludeRule ScopedRule `
                -Output Object `
                -NoSummary
        )

        $PathResults.Count | Should -Be 1
        $PathResults[0].Location | Should -Match 'included\.dsl\.ps1:'
        $ScriptResults.Count | Should -Be 1
        $ScriptResults[0].RuleName | Should -Be 'ScopedRule'
    }

    It 'returns only findings when NoSummary is specified' {
        $Results = @(
            Start-Nitpicking `
                -Script { param([Parameter(Mandatory=$true)] [string] $Name) } `
                -IncludeRule AvoidParameterAttributeBool `
                -Output Object `
                -NoSummary
        )

        $Results.Count | Should -Be 1
        $Results[0].GetType().Name | Should -Be 'NitpickFinding'
    }

    It 'does not invoke editor-disabled rules in editor mode' {
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            throw 'Editor-disabled rule was invoked.'
        }
        Register-Nitpick `
            -Callable $Rule `
            -Name EditorDisabledRule `
            -Source Tests `
            -EditorEnabled:$false

        $Results = @(
            Start-Nitpicking `
                -Script {} `
                -IncludeRule EditorDisabledRule `
                -EditorMode `
                -Output Object `
                -WarningAction SilentlyContinue
        )

        $Results.Count | Should -Be 1
        $Results[0].GetType().Name | Should -Be 'NitpickSummary'
        $Results[0].RuleCount | Should -Be 0
    }

    It 'returns finding and summary text by default' {
        $Script = [scriptblock]::Create(
            'param([Parameter(Mandatory=$true)] [string] $Name)'
        )
        $Results = @(
            Start-Nitpicking `
                -Script $Script.Ast `
                -IncludeRule AvoidParameterAttributeBool
        )

        $Results.Count | Should -Be 2
        $Results[0] | Should -BeOfType ([string])
        $Results[0] | Should -Match '^<ScriptBlock>\r?\n  \d+:\d+  information  Avoid assigning Boolean values to Parameter attribute arguments  AvoidParameterAttributeBool$'
        $Results[1] | Should -BeOfType ([string])
        $Results[1] | Should -Match '^1 finding \(0 errors, 0 warnings, 1 information\) across 1 target in [\d,]+ ms$'
    }

    It 'sorts text findings by source position within each target' {
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            $Variables = @($ScriptBlockAst.FindAll({
                param($Node)
                $Node -is [System.Management.Automation.Language.VariableExpressionAst]
            }, $false))
            foreach ($Variable in $Variables | Sort-Object { $_.Extent.StartLineNumber } -Descending) {
                New-NitpickFinding `
                    -RuleName OutOfOrder `
                    -Message "$($Variable.VariablePath.UserPath) finding" `
                    -ViolationExtent $Variable.Extent `
                    -Severity Information `
                    -RuleSuppressionID OutOfOrder `
                    -ScriptPath '<ScriptBlock>' `
                    -Explanation 'Returns findings out of order.' `
                    -OutputAs NitpickFinding
            }
        }
        Register-Nitpick -Callable $Rule -Name OutOfOrder -Source Tests
        $Script = [scriptblock]::Create("`$First`n`$Second")

        $RenderedOutput = Start-Nitpicking `
            -Script $Script.Ast `
            -IncludeRule OutOfOrder `
            -NoSummary

        $Lines = $RenderedOutput -split '\r?\n'
        $Lines.Count | Should -Be 3
        $Lines[1] | Should -Match '^  1:1\s+information\s+First finding\s+OutOfOrder$'
        $Lines[2] | Should -Match '^  2:1\s+information\s+Second finding\s+OutOfOrder$'
    }

    It 'previews corrections and summarizes final findings for in-memory input' {
        $Source = 'param([Parameter(Mandatory=$true)] [string] $Name)'
        $Results = @(
            Start-Nitpicking `
                -Script $Source `
                -IncludeRule AvoidParameterAttributeBool `
                -Fix `
                -Preview `
                -Output Object
        )
        $Preview = $Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult'
        }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Preview | Should -Not -BeNullOrEmpty
        $Preview.RenderedText | Should -Be 'param([Parameter(Mandatory)] [string] $Name)'
        $Preview.Diff | Should -Match 'Mandatory=\$true'
        $Preview.Diff | Should -Match 'Mandatory'
        $Preview.AcceptedCorrections | Should -HaveCount 1
        $Preview.WasWritten | Should -BeFalse
        $Summary.FindingCount | Should -Be 0
        $Summary.InformationCount | Should -Be 0
    }

    It 'requires Fix when Preview is specified' {
        {
            Start-Nitpicking `
                -Script '$Value = 1' `
                -Preview `
                -NoSummary
        } | Should -Throw 'The Preview switch requires Fix.'
    }

    It 'exposes rejected corrections and conflicts in object output' {
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            $Extent = $ScriptBlockAst.EndBlock.Statements[0].Extent
            $Corrections = @(
                New-NitpickCorrection `
                    -ViolationExtent $Extent `
                    -ReplacementText '$Value = 456' `
                    -FilePathOrContext '<ScriptBlock>' `
                    -Description 'First replacement.' `
                    -RuleName 'ConflictingRule'

                New-NitpickCorrection `
                    -ViolationExtent $Extent `
                    -ReplacementText '$Value = 789' `
                    -FilePathOrContext '<ScriptBlock>' `
                    -Description 'Second replacement.' `
                    -RuleName 'ConflictingRule'
            )

            New-NitpickFinding `
                -RuleName 'ConflictingRule' `
                -Message 'Conflicting correction test.' `
                -ViolationExtent $Extent `
                -Severity Information `
                -RuleSuppressionID 'ConflictingRule' `
                -Corrections $Corrections `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Verifies conflict reporting through Start-Nitpicking.' `
                -OutputAs NitpickFinding
        }
        Register-Nitpick -Callable $Rule -Name ConflictingRule -Source Tests

        $Results = @(
            Start-Nitpicking `
                -Script '$Value = 123' `
                -IncludeRule ConflictingRule `
                -Fix `
                -Preview `
                -Output Object `
                -NoSummary
        )
        $Preview = $Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult'
        }

        $Preview.SkippedCorrections | Should -HaveCount 2
        $Preview.Conflicts | Should -HaveCount 1
        $Preview.RenderedText | Should -Be '$Value = 123'
        $Preview.Diff | Should -Be 'No queued edits.'
    }

    It 'errors for <FindingSeverity> findings at the <ErrorOn> threshold: <ShouldError>' -ForEach $SeverityThresholdCases {
        $RuleName = "Threshold$FindingSeverity"
        $RuleSeverity = $FindingSeverity
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            New-NitpickFinding `
                -RuleName $RuleName `
                -Message 'Threshold test finding' `
                -ViolationExtent $ScriptBlockAst.Extent `
                -Severity $RuleSeverity `
                -RuleSuppressionID $RuleName `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Threshold test finding' `
                -OutputAs NitpickFinding
        }.GetNewClosure()

        Register-Nitpick -Callable $Rule -Name $RuleName -Source Tests

        $ThresholdErrors = @()
        $null = Start-Nitpicking `
            -Script {} `
            -IncludeRule $RuleName `
            -ErrorOn $ErrorOn `
            -NoSummary `
            -ErrorAction SilentlyContinue `
            -ErrorVariable ThresholdErrors

        ($ThresholdErrors.Count -gt 0) | Should -Be $ShouldError
    }
}
