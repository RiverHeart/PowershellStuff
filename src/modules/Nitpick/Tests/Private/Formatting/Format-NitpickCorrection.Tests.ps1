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
            $Proposal = [pscustomobject]@{
                Status = $ProposalStatus
                AcceptedCorrections = $Accepted
                SkippedCorrections = $Skipped
                Conflicts = $Conflicts
                Diff = "29:13  Reason`n  29 - old`n     + new"
            }
        }

        [pscustomobject]@{
            Path = $Path
            Proposal = $Proposal
            Application = [pscustomobject]@{
                Status = $ApplicationStatus
                CommittedCorrections = $Committed
                ErrorRecord = $null
            }
        }
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
            [pscustomobject]@{ ChangeSetId = 'Set1' }
            [pscustomobject]@{ ChangeSetId = 'Set1' }
        )
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
        $Accepted = @($ChangeSet) + [pscustomobject]@{ ChangeSetId = $null }
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
