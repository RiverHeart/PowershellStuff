BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\..\AstEditor\AstEditor.psd1" -Force
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force

    function New-TestCorrectionResult {
        param (
            [string] $Path = 'C:\Scripts\Example.ps1',
            [string] $ProposalStatus = 'Ready',
            [string] $ApplicationStatus = 'Preview',
            [object[]] $Accepted = @(),
            [object[]] $Applied = @(),
            [int] $SkippedFindingCount = 0,
            [int] $UndecidedFindingCount = 0,
            [object[]] $Conflicts = @(),
            [switch] $NoProposal
        )

        $NewFinding = {
            New-NitpickFinding -RuleId 'Local/Placeholder' -Message 'Placeholder' `
                -ViolationExtent ([scriptblock]::Create('$Placeholder = 1').Ast.Extent) `
                -Severity Information -ScriptPath $Path -Explanation 'Placeholder.' -OutputAs NitpickFinding
        }

        $Proposal = $null
        if (-not $NoProposal) {
            $Proposal = & (Get-Module Nitpick) { [NitpickCorrectionProposal]::new() }
            $Proposal.Status = $ProposalStatus
            $Proposal.AcceptedCorrections = $Accepted
            $Proposal.SkippedFindings = @(for ($i = 0; $i -lt $SkippedFindingCount; $i++) { & $NewFinding })
            $Proposal.UndecidedFindings = @(for ($i = 0; $i -lt $UndecidedFindingCount; $i++) { & $NewFinding })
            $Proposal.Conflicts = $Conflicts
            $Proposal.Diff = "29:13  Reason`n  29 - old`n     + new"
        }

        $Application = @{
            Status = $ApplicationStatus
            AppliedCorrections = $Applied
        }
        if ($ApplicationStatus -eq 'Written') {
            $Application.WriteResult = [pscustomobject]@{ WasWritten = $true; WriteStatus = 'Written' }
        }
        if ($ApplicationStatus -eq 'FailedRead') {
            $Application.ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.IO.IOException]::new('Read failed.'), 'ReadFailure',
                [System.Management.Automation.ErrorCategory]::ReadError, $Path
            )
        }
        New-NitpickCorrectionResult -Path $Path -Proposal $Proposal -Application $Application
    }

    function Format-TestCorrection {
        param ([psobject] $CorrectionResult)

        $Lines = InModuleScope Nitpick -Parameters @{ CorrectionResult = $CorrectionResult } {
            param ($CorrectionResult)
            Format-NitpickCorrection -CorrectionResult $CorrectionResult
        }
        @($Lines) -join "`n"
    }
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Format-NitpickCorrection' {
    BeforeEach {
        # One fix containing two all-or-nothing edits.
        $CoupledFix = @(
            New-NitpickCorrection -TextEdit @(
                New-AstTextEdit -Extent ([scriptblock]::Create('$Value = 1').Ast.Extent) `
                    -ReplacementText '$Value = 2' -Reason 'Coupled fix'
                New-AstTextEdit -Extent ([scriptblock]::Create('$Other = 1').Ast.Extent) `
                    -ReplacementText '$Other = 2' -Reason 'Coupled fix'
            ) -FilePathOrContext '<ScriptBlock>' -Description 'Coupled fix'
        )
    }

    It '<Command> rejects a proposal before executing formatter logic' -ForEach @(
        @{ Command = 'Format-NitpickCorrection' }
        @{ Command = 'Format-NitpickText' }
    ) {
        InModuleScope Nitpick -Parameters @{ Command = $Command } {
            param ($Command)

            $Parameters = @{
                CorrectionResult = [NitpickCorrectionProposal]::new()
                ErrorAction = 'Stop'
            }
            if ($Command -eq 'Format-NitpickText') {
                $Parameters.Ast = {}.Ast
            }

            { & $Command @Parameters } | Should -Throw '*NitpickCorrectionResult*'
        }
    }

    It 'returns nothing when there is no correction activity' {
        $Result = New-TestCorrectionResult -ProposalStatus NoChanges -ApplicationStatus NotAttempted

        Format-TestCorrection $Result | Should -BeNullOrEmpty
    }

    It 'indents the diff without a heading and leaves outer spacing to the caller' {
        $Result = New-TestCorrectionResult -Accepted $CoupledFix

        Format-TestCorrection $Result | Should -BeExactly (@(
            '  29:13  Reason'
            '    29 - old'
            '       + new'
            ''
            '  1 proposed correction.'
        ) -join [Environment]::NewLine)
    }

    It 'states the <Status> outcome once in the trailer' -ForEach @(
        @{ Status = 'Preview'; Trailer = '1 proposed correction.' }
        @{ Status = 'WhatIf'; Trailer = '1 proposed correction.' }
        @{ Status = 'Declined'; Trailer = '1 proposed correction declined.' }
        @{ Status = 'InMemory'; Trailer = '1 correction applied in memory.' }
    ) {
        $Parameters = @{ ApplicationStatus = $Status; Accepted = $CoupledFix }
        if ($Status -eq 'InMemory') { $Parameters.Applied = $CoupledFix }
        $Result = New-TestCorrectionResult @Parameters

        $Text = Format-TestCorrection $Result

        $Text | Should -Match ('\n  ' + [regex]::Escape($Trailer) + '$')
        $Text | Should -Not -Match 'preview|WhatIf|No files changed'
    }

    It 'pluralizes proposed corrections' {
        $Independent = New-NitpickCorrection -ViolationExtent ([scriptblock]::Create('$Third = 1').Ast.Extent) `
            -ReplacementText '$Third = 2' -FilePathOrContext '<ScriptBlock>' -Description 'Independent edit'
        $Accepted = @($CoupledFix) + $Independent
        $Result = New-TestCorrectionResult -Accepted $Accepted

        Format-TestCorrection $Result | Should -Match '\n  2 proposed corrections\.$'
    }

    It 'reports applied corrections once per correction, however many edits each contains' {
        $Result = New-TestCorrectionResult -ApplicationStatus Written -Accepted $CoupledFix -Applied $CoupledFix

        Format-TestCorrection $Result | Should -Match '\n  1 correction applied\.$'
    }

    It 'reports full counts and statuses when findings are skipped or corrections conflict' {
        $Result = New-TestCorrectionResult -ProposalStatus Rejected -ApplicationStatus NotAttempted `
            -SkippedFindingCount 2 -Conflicts @(1)

        Format-TestCorrection $Result | Should -BeExactly (
            '  0 corrections applied, 0 corrections accepted, 2 findings skipped, 1 conflict ' +
            '(proposal: Rejected; application: NotAttempted).'
        )
    }

    It 'reports undecided findings only when present' {
        $Result = New-TestCorrectionResult `
            -ProposalStatus NoChanges `
            -ApplicationStatus NotAttempted `
            -UndecidedFindingCount 1

        Format-TestCorrection $Result | Should -BeExactly (
            '  0 corrections applied, 0 corrections accepted, 0 findings skipped, 1 finding undecided, 0 conflicts ' +
            '(proposal: NoChanges; application: NotAttempted).'
        )
    }

    It 'reports a failure without a proposal' {
        $Result = New-TestCorrectionResult -NoProposal -ApplicationStatus FailedRead

        Format-TestCorrection $Result |
            Should -Match '\(proposal: Unavailable; application: FailedRead\)\.$'
    }
}
