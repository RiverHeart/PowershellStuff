BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force

    $PreviousNoHyperlink = $env:NO_HYPERLINK
    $PreviousForceHyperlink = $env:FORCE_HYPERLINK

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
                Diff = 'DIFF'
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
    $env:NO_HYPERLINK = $PreviousNoHyperlink
    $env:FORCE_HYPERLINK = $PreviousForceHyperlink
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Format-NitpickCorrection' {
    BeforeEach {
        $env:NO_HYPERLINK = '1'
        $env:FORCE_HYPERLINK = $null
        $ChangeSet = @(
            [pscustomobject]@{ ChangeSetId = 'Set1' }
            [pscustomobject]@{ ChangeSetId = 'Set1' }
        )
    }

    It 'returns nothing when there is no correction activity' {
        $Result = New-TestCorrectionResult -ProposalStatus NoChanges -ApplicationStatus NotAttempted

        Format-TestCorrection $Result | Should -BeNullOrEmpty
    }

    It 'names the target in the <Status> heading' -ForEach @(
        @{ Status = 'Preview'; Heading = 'Proposed corrections for C:\Scripts\Example.ps1 (preview):' }
        @{ Status = 'WhatIf'; Heading = 'Proposed corrections for C:\Scripts\Example.ps1 (WhatIf):' }
        @{ Status = 'InMemory'; Heading = 'Proposed corrections for C:\Scripts\Example.ps1 (in-memory):' }
        @{ Status = 'Declined'; Heading = 'Proposed corrections for C:\Scripts\Example.ps1 (not applied):' }
    ) {
        $Result = New-TestCorrectionResult -ApplicationStatus $Status -Accepted $ChangeSet

        $Text = Format-TestCorrection $Result

        $Text | Should -Match ('^' + [regex]::Escape($Heading) + '\nDIFF\n')
    }

    It 'counts a change set as one correction in the trailer' {
        $Result = New-TestCorrectionResult -Accepted $ChangeSet

        Format-TestCorrection $Result |
            Should -Match '\n1 proposed correction\. No files changed \(preview\)\.$'
    }

    It 'leaves spacing between blocks to the caller' {
        $Result = New-TestCorrectionResult -Accepted $ChangeSet

        Format-TestCorrection $Result | Should -Not -Match '\n$'
    }

    It 'reports applied corrections by committed change sets' {
        $Result = New-TestCorrectionResult -ApplicationStatus Written -Accepted $ChangeSet -Committed $ChangeSet

        $Text = Format-TestCorrection $Result

        $Text | Should -Match '^Applied corrections for C:\\Scripts\\Example\.ps1:'
        $Text | Should -Match '1 correction applied\.'
    }

    It 'uses the status heading and full counts when edits are skipped or conflicting' {
        $Result = New-TestCorrectionResult -ProposalStatus Rejected -ApplicationStatus NotAttempted `
            -Skipped @(1, 2) -Conflicts @(1)

        $Text = Format-TestCorrection $Result

        $Text | Should -Match '^Corrections for C:\\Scripts\\Example\.ps1 \(proposal: Rejected; application: NotAttempted\):'
        $Text | Should -Not -Match 'DIFF'
        $Text | Should -Match '0 corrections committed, 0 corrections accepted, 2 edits skipped, 1 conflict\.'
    }

    It 'reports a failure without a proposal' {
        $Result = New-TestCorrectionResult -NoProposal -ApplicationStatus FailedRead

        Format-TestCorrection $Result |
            Should -Match '^Corrections for C:\\Scripts\\Example\.ps1 \(proposal: Unavailable; application: FailedRead\):'
    }

    It 'names script block targets without a link' {
        $env:NO_HYPERLINK = $null
        $env:FORCE_HYPERLINK = '1'
        $Result = New-TestCorrectionResult -Path '<ScriptBlock>' -Accepted $ChangeSet

        Format-TestCorrection $Result | Should -Match '^Proposed corrections for <ScriptBlock> \(preview\):'
    }

    It 'links the target path to its file URI when hyperlinks are enabled' {
        $env:NO_HYPERLINK = $null
        $env:FORCE_HYPERLINK = '1'
        $Result = New-TestCorrectionResult -Accepted $ChangeSet

        $Esc = [char] 27
        $Link = @(
            $Esc, ']8;;file:///C:/Scripts/Example.ps1', $Esc, '\', 'C:\Scripts\Example.ps1', $Esc, ']8;;', $Esc, '\'
        ) -join ''
        (Format-TestCorrection $Result).Contains("Proposed corrections for $Link (preview):") | Should -BeTrue
    }
}
