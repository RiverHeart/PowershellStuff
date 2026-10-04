BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
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

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule TransactionRule -Fix `
            -Output Object -Confirm:$false -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })

        $Result.WasWritten | Should -BeTrue
        $Result.WriteStatus | Should -Be 'Written'
        $Result.FixedCorrections | Should -HaveCount 1
        $Result.FixedFindings | Should -HaveCount 1
        $Result.RemainingFindings | Should -HaveCount 1
        $Result.FinalFindings[0].Location | Should -Be "${Path}:1:1"
        $Findings[0].Severity | Should -Be 'Warning'
        $Summary.ErrorCount | Should -Be 0
        $Summary.WarningCount | Should -Be 1
        $Summary.FixedFindingCount | Should -Be 1
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 2'
    }

    It 'applies built-in corrections as one transaction and preserves the encoded snapshot' {
        $Path = Join-Path $TestDrive 'BuiltIn.ps1'
        $Encoding = [System.Text.UTF8Encoding]::new($true, $true)
        $Source = "# $([char]0x00E9)`r`nparam([Parameter(Mandatory=`$true, ValueFromPipeline=`$true)] [string] `$Name)`r`n"
        $Expected = "# $([char]0x00E9)`r`nparam([Parameter(Mandatory, ValueFromPipeline)] [string] `$Name)`r`n"
        [System.IO.File]::WriteAllText($Path, $Source, $Encoding)

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule AvoidParameterAttributeBool -Fix `
            -Output Object -Confirm:$false -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $ExpectedBytes = [byte[]](@($Encoding.GetPreamble()) + @($Encoding.GetBytes($Expected)))

        $Result.WasWritten | Should -BeTrue
        $Result.FixedCorrections | Should -HaveCount 2
        $Result.FixedFindings | Should -HaveCount 2
        $Result.RemainingFindings.GetType().IsArray | Should -BeTrue
        $Result.RemainingFindings | Should -HaveCount 0
        $Summary.FindingCount | Should -Be 0
        $Summary.FixedFindingCount | Should -Be 2
        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) |
            Should -Be ([Convert]::ToBase64String($ExpectedBytes))
    }

    It 'retains the explicit Preview workflow without writing' {
        $Path = Join-Path $TestDrive 'Preview.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule TransactionRule -Fix -Preview `
            -Output Object -NoSummary -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult' }

        $Result.WriteStatus | Should -Be 'Preview'
        $Result.WasWritten | Should -BeFalse
        $Result.FixedCorrections | Should -HaveCount 0
        $Result.RenderedText | Should -Be '$Value = 2'
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
    }

    It 'honors WhatIf and restores native rule invocation context' {
        $Path = Join-Path $TestDrive 'WhatIf.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        Remove-Variable NitpickInvocationContext -Scope Global -ErrorAction SilentlyContinue

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule TransactionRule -Fix -WhatIf `
            -Output Object -NoSummary -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult' }

        $Result.WriteStatus | Should -Be 'WhatIf'
        $Result.WasWritten | Should -BeFalse
        $Result.RenderedText | Should -Be '$Value = 2'
        $Result.FixedCorrections | Should -HaveCount 0
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
        Get-Variable NitpickInvocationContext -Scope Global -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'returns corrected in-memory text without a destination even under WhatIf' {
        $Source = [scriptblock]::Create('$Value = 1')

        $Results = @(Start-Nitpicking -Script $Source -IncludeRule TransactionRule -Fix -WhatIf `
            -Output Object -NoSummary -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult' }

        $Result.WriteStatus | Should -Be 'InMemory'
        $Result.RenderedText | Should -Be '$Value = 2'
        $Result.WasWritten | Should -BeFalse
        $Result.Document.IsFileBacked | Should -BeFalse
    }

    It 'does not write a file-backed AST supplied through Script' {
        $Path = Join-Path $TestDrive 'AstInput.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Ast = Import-ScriptBlockAst -FilePath $Path

        $Results = @(Start-Nitpicking -Script $Ast -IncludeRule TransactionRule -Fix `
            -Output Object -NoSummary -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult' }

        $Result.WriteStatus | Should -Be 'InMemory'
        $Result.WasWritten | Should -BeFalse
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
    }

    It 'rejects stale source and retains original findings and severity counts' {
        $Path = Join-Path $TestDrive 'Stale.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Errors = @()

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule TransactionRule -Fix `
            -Output Object -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable Errors)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult' }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Result.WriteStatus | Should -Be 'StaleSource'
        $Result.WasWritten | Should -BeFalse
        $Result.FixedCorrections | Should -HaveCount 0
        $Result.FinalFindings[0].Severity | Should -Be 'Error'
        $Result.RenderedText | Should -Be '$Value = 1'
        $Summary.ErrorCount | Should -Be 1
        $Summary.FailedTargetCount | Should -Be 1
        $Result.SkippedCorrections | Should -HaveCount 1
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
            -IncludeRule TransactionRule -Fix `
            -Output Object -NoSummary -Confirm:$false -ErrorAction SilentlyContinue)
        $Transactions = @($Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult'
        })
        $Invalid = $Transactions | Where-Object Path -eq $InvalidPath
        $Valid = $Transactions | Where-Object Path -eq $ValidPath

        $Invalid.WriteStatus | Should -Be 'FailedValidation'
        $Invalid.ParseErrors | Should -Not -BeNullOrEmpty
        $Invalid.FixedCorrections | Should -HaveCount 0
        $Invalid.FinalFindings[0].Severity | Should -Be 'Error'
        $Invalid.FailedValidationFindings | Should -HaveCount 1
        $Invalid.RemainingFindings[0].Severity | Should -Be 'Error'
        $Valid.WriteStatus | Should -Be 'Written'
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

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule TransactionRule -Fix `
            -Output Object -NoSummary -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable Errors)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult' }

        $Result.WriteStatus | Should -Be 'FailedWrite'
        $Result.FixedCorrections | Should -HaveCount 0
        $Result.WasWritten | Should -BeFalse
        $Result.FinalFindings[0].Severity | Should -Be 'Error'
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
            -IncludeRule TransactionRule -Fix `
            -Output Object -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable Errors)
        $Transactions = @($Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult'
        })
        $Invalid = $Transactions | Where-Object Path -eq $InvalidPath
        $Valid = $Transactions | Where-Object Path -eq $ValidPath
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Invalid.WriteStatus | Should -Be 'FailedRead'
        $Invalid.WasWritten | Should -BeFalse
        $Invalid.ErrorRecord | Should -Not -BeNullOrEmpty
        $Valid.WasWritten | Should -BeTrue
        $Summary.TargetCount | Should -Be 2
        $Summary.FailedTargetCount | Should -Be 1
        $Errors | Should -Not -BeNullOrEmpty
        [System.IO.File]::ReadAllBytes($InvalidPath) | Should -HaveCount 3
    }

    It 'reports NoChanges without writing a target that has no corrections' {
        $Path = Join-Path $TestDrive 'NoChanges.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 2')
        Mock Save-AstDocument -ModuleName Nitpick { throw 'An unchanged target must not be saved.' }

        $Results = @(Start-Nitpicking -Path $Path -IncludeRule TransactionRule -Fix `
            -Output Object -NoSummary -Confirm:$false -ErrorAction Stop)
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionPreviewResult' }

        $Result.WriteStatus | Should -Be 'NoChanges'
        $Result.WasWritten | Should -BeFalse
        $Result.RemainingFindings | Should -HaveCount 1
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly
    }
}
