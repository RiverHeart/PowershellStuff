BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force

    function New-TestCorrectionResult {
        param (
            [string] $Path = 'C:\Scripts\Example.ps1',
            [string] $ProposalStatus = 'Ready',
            [string] $ApplicationStatus = 'Preview',
            [object[]] $Accepted = @(),
            [object[]] $Committed = @(),
            [object[]] $Skipped = @(),
            [object[]] $Conflicts = @(),
            [switch] $NoProposal
        )

        $Proposal = $null
        if (-not $NoProposal) {
            $Proposal = & (Get-Module Nitpick) { [NitpickCorrectionProposal]::new() }
            $Proposal.Status = $ProposalStatus
            $Proposal.AcceptedCorrections = $Accepted
            $Proposal.SkippedCorrections = $Skipped
            $Proposal.Conflicts = $Conflicts
            $Proposal.Diff = "29:13  Reason`n  29 - old`n     + new"
        }

        $Application = @{
            Status = $ApplicationStatus
            CommittedCorrections = $Committed
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
        $ChangeSet = @(
            New-NitpickCorrection -ViolationExtent ([scriptblock]::Create('$Value = 1').Ast.Extent) `
                -ReplacementText '$Value = 2' -FilePathOrContext '<ScriptBlock>' -Description 'First edit' -ChangeSetId Set1
            New-NitpickCorrection -ViolationExtent ([scriptblock]::Create('$Other = 1').Ast.Extent) `
                -ReplacementText '$Other = 2' -FilePathOrContext '<ScriptBlock>' -Description 'Second edit' -ChangeSetId Set1
        )
    }

    It '<Command> rejects a proposal before executing formatter logic' -ForEach @(
        @{ Command = 'Format-NitpickCorrection' }
        @{ Command = 'Format-NitpickText' }
    ) {
        InModuleScope Nitpick -Parameters @{ Command = $Command } {
            param ($Command)

            Mock Get-NitpickCorrectionCount { throw 'Counting must not be reached.' }
            $Parameters = @{
                CorrectionResult = [NitpickCorrectionProposal]::new()
                ErrorAction = 'Stop'
            }
            if ($Command -eq 'Format-NitpickText') {
                $Parameters.Ast = {}.Ast
            }

            { & $Command @Parameters } | Should -Throw '*NitpickCorrectionResult*'
            Should -Invoke Get-NitpickCorrectionCount -Times 0 -Exactly
        }
    }

    It 'returns nothing when there is no correction activity' {
        $Result = New-TestCorrectionResult -ProposalStatus NoChanges -ApplicationStatus NotAttempted

        Format-TestCorrection $Result | Should -BeNullOrEmpty
    }

    It 'indents the diff without a heading and leaves outer spacing to the caller' {
        $Result = New-TestCorrectionResult -Accepted $ChangeSet

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
        $Result = New-TestCorrectionResult -ApplicationStatus $Status -Accepted $ChangeSet

        $Text = Format-TestCorrection $Result

        $Text | Should -Match ('\n  ' + [regex]::Escape($Trailer) + '$')
        $Text | Should -Not -Match 'preview|WhatIf|No files changed'
    }

    It 'pluralizes proposed corrections by change set' {
        $Independent = New-NitpickCorrection -ViolationExtent ([scriptblock]::Create('$Third = 1').Ast.Extent) `
            -ReplacementText '$Third = 2' -FilePathOrContext '<ScriptBlock>' -Description 'Independent edit'
        $Accepted = @($ChangeSet) + $Independent
        $Result = New-TestCorrectionResult -Accepted $Accepted

        Format-TestCorrection $Result | Should -Match '\n  2 proposed corrections\.$'
    }

    It 'reports applied corrections by committed change sets' {
        $Result = New-TestCorrectionResult -ApplicationStatus Written -Accepted $ChangeSet -Committed $ChangeSet

        Format-TestCorrection $Result | Should -Match '\n  1 correction applied\.$'
    }

    It 'reports full counts and statuses when edits are skipped or conflicting' {
        $Result = New-TestCorrectionResult -ProposalStatus Rejected -ApplicationStatus NotAttempted `
            -Skipped @(1, 2) -Conflicts @(1)

        Format-TestCorrection $Result | Should -BeExactly (
            '  0 corrections committed, 0 corrections accepted, 2 edits skipped, 1 conflict ' +
            '(proposal: Rejected; application: NotAttempted).'
        )
    }

    It 'reports a failure without a proposal' {
        $Result = New-TestCorrectionResult -NoProposal -ApplicationStatus FailedRead

        Format-TestCorrection $Result |
            Should -Match '\(proposal: Unavailable; application: FailedRead\)\.$'
    }
}
