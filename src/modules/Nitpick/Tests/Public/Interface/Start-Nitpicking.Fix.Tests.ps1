BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force

    # Keep text assertions independent of the host terminal's hyperlink support.
    $PreviousNoHyperlink = $env:NO_HYPERLINK
    $PreviousForceHyperlink = $env:FORCE_HYPERLINK
    $env:NO_HYPERLINK = '1'
    $env:FORCE_HYPERLINK = $null
}

AfterAll {
    $env:NO_HYPERLINK = $PreviousNoHyperlink
    $env:FORCE_HYPERLINK = $PreviousForceHyperlink
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Start-Nitpicking transactional fixes' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            $Assignment = $ScriptBlockAst.EndBlock.Statements | Select-Object -First 1
            if (-not $Assignment -or $Assignment.Extent.Text -notin '$Value = 1', '$Value = 2') {
                return
            }
            $Severity = 'Warning'
            $Corrections = @()
            $Context = if ($Assignment.Extent.File) { $Assignment.Extent.File } else { '<ScriptBlock>' }
            if ($Assignment.Extent.Text -eq '$Value = 1') {
                $Severity = 'Error'
                $Replacement = if ($Assignment.Extent.File -like '*Invalid.ps1') {
                    'if ('
                } else {
                    '$Value = 2'
                }
                $Corrections = @(
                    New-NitpickCorrection `
                        -ViolationExtent $Assignment.Extent `
                        -ReplacementText $Replacement `
                        -FilePathOrContext $Context `
                        -Description 'Replace value' `
                        -RuleName TransactionRule
                )
                if ($Assignment.Extent.File -like '*Stale.ps1') {
                    [System.IO.File]::WriteAllText($Assignment.Extent.File, '$Value = 3')
                }
            }
            New-NitpickFinding `
                -RuleName TransactionRule `
                -Message 'Transaction finding' `
                -ViolationExtent $Assignment.Extent `
                -Severity $Severity `
                -RuleSuppressionID TransactionRule `
                -ScriptPath $Context `
                -Corrections $Corrections `
                -Explanation 'Verifies committed versus candidate analysis.'
        }
        Register-Nitpick -Callable $Rule -Name TransactionRule -Source Tests
    }

    It 'commits a file and calculates output, severity counts, and threshold from final analysis' {
        $Path = Join-Path $TestDrive 'Apply.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Local/TransactionRule -Fix `
            -Output Object -Confirm:$false -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })

        $Result.Application.WriteResult.WasWritten | Should -BeTrue
        $Result.Application.Status | Should -Be 'Written'
        $Result.Application.CommittedCorrections | Should -HaveCount 1
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 1
        $Result.Report.EffectiveFindings | Should -HaveCount 1
        $Result.Report.EffectiveFindings[0].Location | Should -Be "${Path}:1:1"
        $Result.Report.FindingsWithCommittedCorrections[0] | Should -Be $Result.Proposal.OriginalFindings[0]
        $Result.Report.FindingsWithCommittedCorrections[0].Severity | Should -Be 'Error'

        $Findings[0].Severity | Should -Be 'Warning'

        $Summary.ErrorCount | Should -Be 0
        $Summary.WarningCount | Should -Be 1
        $Summary.FindingsWithCommittedCorrectionsCount | Should -Be 1
        $Summary.PSObject.Properties.Name | Should -Not -Contain 'FixedFindingCount'

        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 2'
    }

    It 'applies built-in corrections as one transaction and preserves the encoded snapshot' {
        $Path = Join-Path $TestDrive 'BuiltIn.ps1'
        $Encoding = [System.Text.UTF8Encoding]::new($true, $true)
        $Source = "# $([char]0x00E9)`r`nparam([Parameter(Mandatory=`$true, ValueFromPipeline=`$true)] [string] `$Name)`r`n"
        $Expected = "# $([char]0x00E9)`r`nparam([Parameter(Mandatory, ValueFromPipeline)] [string] `$Name)`r`n"
        [System.IO.File]::WriteAllText($Path, $Source, $Encoding)

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Nitpick/AvoidParameterAttributeBool -Fix `
            -Output Object -Confirm:$false -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $ExpectedBytes = [byte[]](@($Encoding.GetPreamble()) + @($Encoding.GetBytes($Expected)))

        $Result.Application.WriteResult.WasWritten | Should -BeTrue
        $Result.Application.CommittedCorrections | Should -HaveCount 2
        $Result.Report.FindingsWithCommittedCorrections | Should -HaveCount 2
        $Result.Report.EffectiveFindings.GetType().IsArray | Should -BeTrue
        $Result.Report.EffectiveFindings | Should -HaveCount 0

        $Summary.FindingCount | Should -Be 0
        $Summary.FindingsWithCommittedCorrectionsCount | Should -Be 2

        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) |
            Should -Be ([Convert]::ToBase64String($ExpectedBytes))
    }

    It 'retains the explicit Preview workflow without writing' {
        $Path = Join-Path $TestDrive 'Preview.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Local/TransactionRule -Fix -Preview `
            -Output Object -NoSummary -ErrorAction Stop)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Result.Application.Status | Should -Be 'Preview'
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Application.CommittedCorrections | Should -HaveCount 0
        $Result.Report.EffectiveText | Should -Be '$Value = 2'

        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
    }

    It 'shows proposed edits in text output without claiming they were committed' {
        $Path = Join-Path $TestDrive 'PreviewText.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')

        $Output = @(
            Start-Nitpicking -Path $Path -IncludeRule Local/TransactionRule -Fix -Preview `
                -Output Text -NoSummary -ErrorAction Stop
        ) -join "`n"

        $Lines = $Output -split '\r?\n'
        $Lines[0] | Should -BeExactly $Path
        @($Lines | Where-Object { $_ -eq $Path }).Count | Should -Be 1
        $Output | Should -Match '1 - \$Value = 1'
        $Output | Should -Match '\+ \$Value = 2'
        $Output | Should -Match '\$Value = 2'
        $Lines[-1] | Should -BeExactly '  1 proposed correction.'
        $Output | Should -Not -MatchExactly '\(preview\)|No files changed'
        $Output | Should -Not -Match 'committed'
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
    }

    It 'counts a coordinated change set as one proposed correction in text output' {
        $Path = Join-Path $TestDrive 'CoordinatedPreview.ps1'
        [System.IO.File]::WriteAllText($Path, '-not ($Value -is [int])')

        $Output = @(
            Start-Nitpicking -Path $Path -IncludeRule Nitpick/UseIsNotOperator -Fix -Preview `
                -Output Text -NoSummary -ErrorAction Stop
        ) -join "`n"

        $Output | Should -Match "(?m)^  (\e\[1m)?1:1  Replace .* with "
        $Output | Should -Not -Match '\[0, 1\]'
        $Output | Should -Match '  1 proposed correction\.'
        $Output | Should -Not -Match '2 proposed'
    }

    It 'separates consecutive target blocks with host-only blank lines' {
        $Directory = New-Item -Path (Join-Path $TestDrive 'Separated') -ItemType Directory
        foreach ($Name in 'First.ps1', 'Second.ps1') {
            [System.IO.File]::WriteAllText((Join-Path $Directory $Name), '-not ($Value -is [int])')
        }

        $Output = @(Start-Nitpicking -Path $Directory.FullName -IncludeRule Nitpick/UseIsNotOperator -Fix -Preview `
            -Output Text -NoSummary -ErrorAction Stop 6>$null)
        $Combined = @(Start-Nitpicking -Path $Directory.FullName -IncludeRule Nitpick/UseIsNotOperator -Fix -Preview `
            -Output Text -NoSummary -ErrorAction Stop 6>&1)

        $Output | Where-Object { $_ -eq '' } | Should -BeNullOrEmpty
        $SecondPath = [regex]::Escape((Join-Path $Directory.FullName 'Second.ps1'))
        $SecondIndex = @(0..($Combined.Count - 1) | Where-Object {
            "$($Combined[$_])" -match "^$SecondPath(\r?\n|$)"
        })[0]
        $SecondIndex | Should -BeGreaterThan 0
        "$($Combined[$SecondIndex - 1])" | Should -BeExactly ''
        $Combined[$SecondIndex - 1] | Should -BeOfType ([System.Management.Automation.InformationRecord])
    }

    It 'omits the correction block when there are no edits but retains findings' {
        $Path = Join-Path $TestDrive 'NoCorrectionText.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 2')

        $Output = @(
            Start-Nitpicking -Path $Path -IncludeRule Local/TransactionRule -Fix `
                -Output Text -NoSummary -Confirm:$false -ErrorAction Stop
        ) -join "`n"

        $Output | Should -Match 'Transaction finding'
        $Output | Should -Not -Match 'proposal:'
        $Output | Should -Not -Match 'No queued edits'
        $Output | Should -Not -Match 'committed, .* accepted, .* skipped'
    }

    It 'honors WhatIf and restores native rule invocation context' {
        $Path = Join-Path $TestDrive 'WhatIf.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        Remove-Variable NitpickInvocationContext -Scope Global -ErrorAction SilentlyContinue

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Local/TransactionRule -Fix -WhatIf `
            -Output Object -NoSummary -ErrorAction Stop)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Result.Application.Status | Should -Be 'WhatIf'
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Report.EffectiveText | Should -Be '$Value = 2'
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'

        Get-Variable NitpickInvocationContext -Scope Global -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'returns corrected in-memory text without a destination even under WhatIf' {
        $Source = [scriptblock]::Create('$Value = 1')

        $Results = @(Start-Nitpicking -Script $Source -IncludeRule Local/TransactionRule -Fix -WhatIf `
            -Output Object -NoSummary -ErrorAction Stop)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Result.Application.Status | Should -Be 'InMemory'
        $Result.Report.EffectiveText | Should -Be '$Value = 2'
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Proposal.Document.IsFileBacked | Should -BeFalse
    }

    It 'does not write a file-backed AST supplied through Script' {
        $Path = Join-Path $TestDrive 'AstInput.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Ast = Import-ScriptBlockAst -FilePath $Path

        $Results = @(Start-Nitpicking -Script $Ast -IncludeRule Local/TransactionRule -Fix `
            -Output Object -NoSummary -ErrorAction Stop)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Result.Application.Status | Should -Be 'InMemory'
        $Result.Application.CommittedCorrections | Should -HaveCount 0

        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
    }

    It 'rejects stale source and retains original findings and severity counts' {
        $Path = Join-Path $TestDrive 'Stale.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Errors = @()

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Local/TransactionRule -Fix `
            -Output Object -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable Errors)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Result.Application.Status | Should -Be 'StaleSource'
        $Result.Application.WriteResult.WasWritten | Should -BeFalse
        $Result.Application.CommittedCorrections | Should -HaveCount 0
        $Result.Report.EffectiveFindings[0].Severity | Should -Be 'Error'
        $Result.Report.EffectiveText | Should -Be '$Value = 1'
        $Result.Report.AnalysisSource | Should -Be 'Original'
        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.SkippedCorrections | Should -HaveCount 0

        $Summary.ErrorCount | Should -Be 1
        $Summary.FailedTargetCount | Should -Be 1
        $Summary.SkippedCorrectionCount | Should -Be 0
        $Errors | Should -Not -BeNullOrEmpty

        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 3'

        @(Get-ChildItem $TestDrive -Filter '*.tmp' -Force) | Should -HaveCount 0
    }

    It 'does not apply invalid candidate text and continues with another target' {
        $InvalidPath = Join-Path $TestDrive 'Invalid.ps1'
        $ValidPath = Join-Path $TestDrive 'Valid.ps1'
        [System.IO.File]::WriteAllText($InvalidPath, '$Value = 1')
        [System.IO.File]::WriteAllText($ValidPath, '$Value = 1')

        $Results = @(Start-Nitpicking -Path $TestDrive -IncludePath $InvalidPath, $ValidPath `
            -IncludeRule Local/TransactionRule -Fix `
            -Output Object -Confirm:$false -ErrorAction SilentlyContinue)
        $Transactions = @($Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionResult'
        })
        $Invalid = $Transactions | Where-Object Path -eq $InvalidPath
        $Valid = $Transactions | Where-Object Path -eq $ValidPath
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Invalid.Proposal.Status | Should -Be 'FailedValidation'
        $Invalid.Proposal.ParseErrors | Should -Not -BeNullOrEmpty
        $Invalid.Proposal.CandidateText | Should -Be 'if ('

        $Invalid.Application.Status | Should -Be 'NotAttempted'
        $Invalid.Application.CommittedCorrections | Should -HaveCount 0

        $Invalid.Report.EffectiveFindings[0].Severity | Should -Be 'Error'
        $Invalid.Report.AnalysisSource | Should -Be 'Original'
        $Invalid.Report.EffectiveText | Should -Be '$Value = 1'

        $Valid.Application.Status | Should -Be 'Written'

        $Summary.TargetCount | Should -Be 2
        $Summary.FailedTargetCount | Should -Be 1
        $Summary.SkippedCorrectionCount | Should -Be 1
        $Summary.FindingsWithCommittedCorrectionsCount | Should -Be 1

        [System.IO.File]::ReadAllText($InvalidPath) | Should -Be '$Value = 1'
        [System.IO.File]::ReadAllText($ValidPath) | Should -Be '$Value = 2'
    }

    It 'reports replacement failures instead of claiming corrections were fixed' {
        $Path = Join-Path $TestDrive 'FailedWrite.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        Mock Invoke-AstFileReplacement -ModuleName AstEditor {
            throw [System.IO.IOException]::new('Simulated commit failure.')
        }
        $Errors = @()

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Local/TransactionRule -Fix `
            -Output Object -NoSummary -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable Errors)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Result.Application.Status | Should -Be 'FailedWrite'
        $Result.Application.CommittedCorrections | Should -HaveCount 0
        $Result.Application.WriteResult.WasWritten | Should -BeFalse

        $Result.Report.EffectiveFindings[0].Severity | Should -Be 'Error'

        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Proposal.SkippedCorrections | Should -HaveCount 0

        $Errors | Should -Not -BeNullOrEmpty

        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'

        @(Get-ChildItem $TestDrive -Filter '*.tmp' -Force) | Should -HaveCount 0
    }

    It 'reports undecodable sources and still commits a separate valid target' {
        $InvalidPath = Join-Path $TestDrive 'Legacy.ps1'
        $ValidPath = Join-Path $TestDrive 'Valid.ps1'
        [System.IO.File]::WriteAllBytes($InvalidPath, [byte[]](0x23, 0x20, 0xE9))
        [System.IO.File]::WriteAllText($ValidPath, '$Value = 1')
        $Errors = @()

        $Results = @(Start-Nitpicking -Path $TestDrive -IncludePath $InvalidPath, $ValidPath `
            -IncludeRule Local/TransactionRule -Fix `
            -Output Object -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable Errors)

        $Transactions = @($Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionResult'
        })

        $Invalid = $Transactions | Where-Object Path -eq $InvalidPath
        $Valid = $Transactions | Where-Object Path -eq $ValidPath
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Invalid.Proposal | Should -BeNullOrEmpty

        $Invalid.Application.Status | Should -Be 'FailedRead'
        $Invalid.Application.CommittedCorrections | Should -HaveCount 0
        $Invalid.Application.WriteResult | Should -BeNullOrEmpty
        $Invalid.Application.ErrorRecord | Should -Not -BeNullOrEmpty

        $Invalid.Report.AnalysisSource | Should -Be 'None'
        ($null -eq $Invalid.Report.EffectiveText) | Should -BeTrue
        $Invalid.Report.EffectiveFindings -is [array] | Should -BeTrue
        $Invalid.Report.EffectiveFindings | Should -HaveCount 0
        $Invalid.Report.FindingsWithCommittedCorrections -is [array] | Should -BeTrue
        $Invalid.Report.FindingsWithCommittedCorrections | Should -HaveCount 0

        $Valid.Application.WriteResult.WasWritten | Should -BeTrue

        $Summary.TargetCount | Should -Be 2
        $Summary.FailedTargetCount | Should -Be 1

        $Errors | Should -Not -BeNullOrEmpty
        [System.IO.File]::ReadAllBytes($InvalidPath) | Should -HaveCount 3
    }

    It 'reports NoChanges without writing a target that has no corrections' {
        $Path = Join-Path $TestDrive 'NoChanges.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 2')
        Mock Save-AstDocument -ModuleName Nitpick { throw 'An unchanged target must not be saved.' }

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule Local/TransactionRule -Fix `
            -Output Object -NoSummary -Confirm:$false -ErrorAction Stop)

        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
        $Result.Proposal.Status | Should -Be 'NoChanges'
        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Application.CommittedCorrections | Should -HaveCount 0
        $Result.Report.EffectiveFindings | Should -HaveCount 1
        $Result.Report.AnalysisSource | Should -Be 'Candidate'
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }
}
