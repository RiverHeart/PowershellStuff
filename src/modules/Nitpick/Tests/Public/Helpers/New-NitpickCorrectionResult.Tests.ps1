[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Pester consumes BeforeEach variables in It blocks.'
)]
param ()

BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickCorrectionResult' {
    BeforeEach {
        $Correction = [pscustomobject]@{ Description = 'Replace value' }
        $Finding = [pscustomobject]@{ Message = 'Original finding' }
        $Proposal = [pscustomobject]@{
            PSTypeName = 'Nitpick.CorrectionProposal'
            Status = 'Ready'
            WasReanalyzed = $true
            AcceptedCorrections = @($Correction)
            ParseErrors = @()
        }
        $WriteResult = [pscustomobject]@{ WriteStatus = 'Written'; WasWritten = $true }
        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.IO.IOException]::new('Read failed.'),
            'ReadFailure',
            [System.Management.Automation.ErrorCategory]::ReadError,
            'Example.ps1'
        )
    }

    It 'exports the factory and declares its output type' {
        $Command = Get-Command New-NitpickCorrectionResult -Module Nitpick

        $Command.OutputType.Name | Should -Contain 'Nitpick.CorrectionResult'
        foreach ($Parameter in @('Path', 'Proposal', 'Application', 'Report')) {
            $Command.Parameters.Keys | Should -Contain $Parameter
        }
        $Command.Parameters.Path.ParameterType | Should -Be ([string])
        $Command.Parameters.Proposal.ParameterType | Should -Be ([psobject])
        $Command.Parameters.Application.ParameterType | Should -Be ([hashtable])
        $Command.Parameters.Report.ParameterType | Should -Be ([hashtable])
    }

    It 'creates exactly the envelope schema with empty arrays and null diagnostics' {
        $Result = New-NitpickCorrectionResult

        $Result.PSTypeNames[0] | Should -Be 'Nitpick.CorrectionResult'
        $Result.Path | Should -Be '<ScriptBlock>'
        $Result.Proposal | Should -BeNullOrEmpty

        @($Result.PSObject.Properties.Name | Sort-Object) -join ',' |
            Should -Be 'Application,Path,Proposal,Report'

        @($Result.Application.PSObject.Properties.Name | Sort-Object) -join ',' |
            Should -Be 'CommittedCorrections,ErrorRecord,Status,WriteResult'

        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Application.CommittedCorrections -is [array] | Should -BeTrue
        $Result.Application.CommittedCorrections | Should -HaveCount 0
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Application.ErrorRecord | Should -BeNullOrEmpty

        @($Result.Report.PSObject.Properties.Name | Sort-Object) -join ',' |
            Should -Be 'AnalysisSource,EffectiveFindings,EffectiveText,FindingsWithCommittedCorrections'

        $Result.Report.AnalysisSource | Should -Be 'None'

        ($null -eq $Result.Report.EffectiveText) | Should -BeTrue

        foreach ($Property in @('EffectiveFindings', 'FindingsWithCommittedCorrections')) {
            $Result.Report.$Property -is [array] | Should -BeTrue
            $Result.Report.$Property | Should -HaveCount 0
        }
    }

    It 'retains the proposal reference and supplied application and report values' {
        $Result = New-NitpickCorrectionResult -Path 'Example.ps1' -Proposal $Proposal `
            -Application @{
                Status = 'Written'
                CommittedCorrections = @($Correction)
                WriteResult = $WriteResult
            } -Report @{
                AnalysisSource = 'Candidate'
                EffectiveText = '$Value = 2'
                EffectiveFindings = @($Finding)
                FindingsWithCommittedCorrections = @($Finding)
            }

        $Result.Path | Should -Be 'Example.ps1'
        [object]::ReferenceEquals($Result.Proposal, $Proposal) | Should -BeTrue

        $Result.Application.Status | Should -Be 'Written'
        $Result.Application.CommittedCorrections[0] | Should -Be $Correction
        $Result.Application.WriteResult | Should -Be $WriteResult
        $Result.Application.ErrorRecord | Should -BeNullOrEmpty

        $Result.Report.AnalysisSource | Should -Be 'Candidate'
        $Result.Report.EffectiveText | Should -Be '$Value = 2'
        $Result.Report.EffectiveFindings[0] | Should -Be $Finding
        $Result.Report.FindingsWithCommittedCorrections[0] | Should -Be $Finding
    }

    It 'normalizes zero and single supplied collections to arrays' -ForEach @(
        @{ Single = $false; Count = 0 }
        @{ Single = $true; Count = 1 }
    ) {
        $Corrections = if ($Single) { $Correction } else { @() }
        $Findings = if ($Single) { $Finding } else { @() }
        $Result = New-NitpickCorrectionResult `
            -Proposal $Proposal `
            -Application @{ Status = 'Written'; WriteResult = $WriteResult; CommittedCorrections = $Corrections } `
            -Report @{
                AnalysisSource = 'Candidate'
                EffectiveFindings = $Findings
                FindingsWithCommittedCorrections = $Findings
            }

        $Result.Application.CommittedCorrections -is [array] | Should -BeTrue
        $Result.Application.CommittedCorrections | Should -HaveCount $Count

        foreach ($Property in @('EffectiveFindings', 'FindingsWithCommittedCorrections')) {
            $Result.Report.$Property -is [array] | Should -BeTrue
            $Result.Report.$Property | Should -HaveCount $Count
        }

        $Result.Application.Status | Should -Be 'Written'
        $Result.Report.AnalysisSource | Should -Be 'Candidate'
    }

    It 'preserves empty effective source when original analysis is available' {
        $Result = New-NitpickCorrectionResult -Proposal $Proposal `
            -Report @{ AnalysisSource = 'Original'; EffectiveText = '' }

        ($null -eq $Result.Report.EffectiveText) | Should -BeFalse
        $Result.Report.EffectiveText | Should -BeExactly ''
    }

    It 'rejects unknown application and report keys instead of creating compatibility groups' {
        { New-NitpickCorrectionResult -Application @{ Fixed = @() } } | Should -Throw
        { New-NitpickCorrectionResult -Report @{ Remaining = @() } } | Should -Throw
    }

    It 'rejects invalid application status <Label>' -ForEach @(
        @{ Label = 'unknown'; Status = 'Writen' }
        @{ Label = 'null'; Status = $null }
        @{ Label = 'empty'; Status = '' }
        @{ Label = 'array'; Status = @('Written', 'Preview') }
    ) {
        { New-NitpickCorrectionResult -Proposal $Proposal -Application @{ Status = $Status } } |
            Should -Throw '*Application.Status*'
    }

    It 'rejects invalid analysis source <Label>' -ForEach @(
        @{ Label = 'unknown'; Source = 'Final' }
        @{ Label = 'null'; Source = $null }
        @{ Label = 'empty'; Source = '' }
        @{ Label = 'array'; Source = @('Original', 'Candidate') }
    ) {
        { New-NitpickCorrectionResult -Proposal $Proposal -Report @{ AnalysisSource = $Source } } |
            Should -Throw '*Report.AnalysisSource*'
    }

    It 'rejects an unrecognized proposal status' {
        $Proposal.Status = 'Preview'
        { New-NitpickCorrectionResult -Proposal $Proposal } | Should -Throw '*Proposal.Status*'
    }

    It 'rejects attempting application of a non-ready proposal' -ForEach @(
        @{ Status = 'Rejected' }
        @{ Status = 'FailedValidation' }
        @{ Status = 'NoChanges' }
    ) {
        $Proposal.Status = $Status
        { New-NitpickCorrectionResult -Proposal $Proposal -Application @{ Status = 'Preview' } } |
            Should -Throw '*Only a Ready proposal*'
    }

    It 'rejects committed corrections under <Status>' -ForEach @(
        @{ Status = 'NotAttempted' }
        @{ Status = 'Preview' }
        @{ Status = 'WhatIf' }
        @{ Status = 'Declined' }
        @{ Status = 'InMemory' }
        @{ Status = 'FailedValidation' }
        @{ Status = 'StaleSource' }
        @{ Status = 'StaleTarget' }
        @{ Status = 'InvalidTarget' }
        @{ Status = 'FailedWrite' }
    ) {
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ Status = $Status; CommittedCorrections = @($Correction) } } |
            Should -Throw '*require a Written application*'
    }

    It 'rejects attributed findings without a written application' {
        { New-NitpickCorrectionResult -Proposal $Proposal -Report @{
            AnalysisSource = 'Original'
            FindingsWithCommittedCorrections = @($Finding)
        } } | Should -Throw '*require a Written application*'
    }

    It 'requires successful persistence evidence for Written' -ForEach @(
        @{ Evidence = $null }
        @{ Evidence = [pscustomobject]@{ WasWritten = $false; WriteStatus = 'FailedWrite' } }
        @{ Evidence = [pscustomobject]@{ WasWritten = $true; WriteStatus = 'FailedWrite' } }
    ) {
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ Status = 'Written'; WriteResult = $Evidence } } |
            Should -Throw '*successful AstEditor write result*'
    }

    It 'rejects committing a correction outside the accepted proposal' {
        { New-NitpickCorrectionResult -Proposal $Proposal -Application @{
            Status = 'Written'
            WriteResult = $WriteResult
            CommittedCorrections = @([pscustomobject]@{ Description = 'Unrelated edit' })
        } } | Should -Throw '*proposal accepted corrections*'
    }

    It 'requires a Ready proposal for Written' {
        $Proposal.Status = 'Rejected'
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ Status = 'Written'; WriteResult = $WriteResult } } |
            Should -Throw '*Ready proposal*'
    }

    It 'rejects attributing findings when no corrections were committed' {
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ Status = 'Written'; WriteResult = $WriteResult } `
            -Report @{ AnalysisSource = 'Original'; FindingsWithCommittedCorrections = @($Finding) } } |
            Should -Throw '*none were committed*'
    }

    It 'rejects candidate reporting without valid reanalysis: <Reason>' -ForEach @(
        @{ Reason = 'not reanalyzed'; Status = 'Ready'; Reanalyzed = $false; Errors = @() }
        @{ Reason = 'rejected'; Status = 'Rejected'; Reanalyzed = $true; Errors = @() }
        @{ Reason = 'failed validation'; Status = 'FailedValidation'; Reanalyzed = $true; Errors = @() }
        @{ Reason = 'parse errors'; Status = 'Ready'; Reanalyzed = $true; Errors = @('Parse error') }
    ) {
        $Proposal.Status = $Status
        $Proposal.WasReanalyzed = $Reanalyzed
        $Proposal.ParseErrors = $Errors
        $ApplicationStatus = if ($Status -eq 'Ready') { 'Preview' } else { 'NotAttempted' }
        { New-NitpickCorrectionResult -Proposal $Proposal -Application @{ Status = $ApplicationStatus } `
            -Report @{ AnalysisSource = 'Candidate' } } | Should -Throw '*valid reanalysis*'
    }

    It 'rejects candidate reporting after <Status>' -ForEach @(
        @{ Status = 'Declined' }
        @{ Status = 'FailedWrite' }
        @{ Status = 'StaleSource' }
    ) {
        { New-NitpickCorrectionResult -Proposal $Proposal -Application @{ Status = $Status } `
            -Report @{ AnalysisSource = 'Candidate' } } | Should -Throw '*valid reanalysis*'
    }

    It 'accepts candidate reporting for a no-change reanalysis' {
        $Proposal.Status = 'NoChanges'
        $Result = New-NitpickCorrectionResult -Proposal $Proposal -Report @{ AnalysisSource = 'Candidate' }
        $Result.Report.AnalysisSource | Should -Be 'Candidate'
        $Result.Application.Status | Should -Be 'NotAttempted'
    }

    It 'rejects analysis or application without a proposal' {
        { New-NitpickCorrectionResult -Report @{ AnalysisSource = 'Original' } } |
            Should -Throw '*require a proposal*'
        { New-NitpickCorrectionResult -Report @{ AnalysisSource = 'Candidate' } } |
            Should -Throw '*require a proposal*'
        { New-NitpickCorrectionResult -Application @{ Status = 'Preview' } } |
            Should -Throw '*require a proposal*'
    }

    It 'rejects report content when AnalysisSource is None: <Property>' -ForEach @(
        @{ Property = 'EffectiveText'; Value = '' }
        @{ Property = 'EffectiveFindings'; Value = @('Finding') }
        @{ Property = 'FindingsWithCommittedCorrections'; Value = @('Finding') }
    ) {
        { New-NitpickCorrectionResult -Report @{ $Property = $Value } } |
            Should -Throw '*no analysis*'
    }

    It 'constructs a read failure with no proposal or effective analysis' {
        $Result = New-NitpickCorrectionResult -Application @{ Status = 'FailedRead'; ErrorRecord = $ErrorRecord }
        $Result.Application.ErrorRecord | Should -Be $ErrorRecord
        $Result.Proposal | Should -BeNullOrEmpty
        $Result.Report.AnalysisSource | Should -Be 'None'
        $Result.Report.EffectiveText | Should -BeNullOrEmpty
        $Result.Report.EffectiveFindings | Should -HaveCount 0
    }

    It 'rejects read failures with a proposal, analysis, or missing error' {
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ Status = 'FailedRead'; ErrorRecord = $ErrorRecord } } |
            Should -Throw '*FailedRead requires*'

        { New-NitpickCorrectionResult -Application @{ Status = 'FailedRead'; ErrorRecord = $ErrorRecord } `
            -Report @{ AnalysisSource = 'Original' } } | Should -Throw

        { New-NitpickCorrectionResult -Application @{ Status = 'FailedRead' } } |
            Should -Throw '*FailedRead requires*'
    }

    It 'does not share mutable application or report state between instances' {
        $First = New-NitpickCorrectionResult
        $Second = New-NitpickCorrectionResult

        $First.Application.CommittedCorrections += 'committed'
        $First.Application.Status = 'Written'
        $First.Report.EffectiveFindings += 'finding'
        $First.Report.AnalysisSource = 'Candidate'

        $Second.Application.CommittedCorrections | Should -HaveCount 0
        $Second.Application.Status | Should -Be 'NotAttempted'
        $Second.Report.EffectiveFindings | Should -HaveCount 0
        $Second.Report.AnalysisSource | Should -Be 'None'
    }
}
