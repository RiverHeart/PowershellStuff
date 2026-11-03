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
        $Extent = [scriptblock]::Create('$Value = 1').Ast.EndBlock.Statements[0].Extent
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Value = 2' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace value'

        $Finding = New-NitpickFinding `
            -ViolationExtent $Extent `
            -Message 'Original finding' `
            -RuleId 'Local/TestRule' `
            -Severity Information `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Constructor fixture'

        $Proposal = & (Get-Module Nitpick) { [NitpickCorrectionProposal]::new() }
        $Proposal.Status = 'Ready'
        $Proposal.WasReanalyzed = $true
        $Proposal.AcceptedCorrections = @($Correction)

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

        $Command.OutputType.Name | Should -Contain 'NitpickCorrectionResult'
        foreach ($Parameter in @('Path', 'Proposal', 'Application', 'Report')) {
            $Command.Parameters.Keys | Should -Contain $Parameter
        }
        $Command.Parameters.Path.ParameterType | Should -Be ([string])
        $Command.Parameters.Proposal.ParameterType.Name | Should -Be 'NitpickCorrectionProposal'
        $Command.Parameters.Application.ParameterType | Should -Be ([hashtable])
        $Command.Parameters.Report.ParameterType | Should -Be ([hashtable])
    }

    It 'creates exactly the envelope schema with empty arrays and null diagnostics' {
        $Result = New-NitpickCorrectionResult

        $Result.PSTypeNames[0] | Should -Be 'NitpickCorrectionResult'
        $Result.GetType().Name | Should -Be 'NitpickCorrectionResult'
        $Result.Application.GetType().Name | Should -Be 'NitpickCorrectionApplication'
        $Result.Report.GetType().Name | Should -Be 'NitpickCorrectionReport'
        $Result.Path | Should -Be '<ScriptBlock>'
        $Result.Proposal | Should -BeNullOrEmpty

        @($Result.PSObject.Properties.Name | Sort-Object) -join ',' |
            Should -Be 'Application,Path,Proposal,Report'

        @($Result.Application.PSObject.Properties.Name | Sort-Object) -join ',' |
            Should -Be 'AppliedCorrections,ErrorRecord,Status,WriteResult'

        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Application.AppliedCorrections -is [array] | Should -BeTrue
        $Result.Application.AppliedCorrections | Should -HaveCount 0
        $Result.Application.WriteResult | Should -BeNullOrEmpty
        $Result.Application.ErrorRecord | Should -BeNullOrEmpty

        @($Result.Report.PSObject.Properties.Name | Sort-Object) -join ',' |
            Should -Be 'AnalysisSource,EffectiveFindings,EffectiveText,FindingsWithAcceptedCorrections,FindingsWithAppliedCorrections'

        $Result.Report.AnalysisSource | Should -Be 'None'

        ($null -eq $Result.Report.EffectiveText) | Should -BeTrue

        foreach ($Property in @('EffectiveFindings', 'FindingsWithAppliedCorrections', 'FindingsWithAcceptedCorrections')) {
            $Result.Report.$Property -is [array] | Should -BeTrue
            $Result.Report.$Property | Should -HaveCount 0
        }
    }

    It 'retains the proposal reference and supplied application and report values' {
        $Result = New-NitpickCorrectionResult -Path 'Example.ps1' -Proposal $Proposal `
            -Application @{
                Status = 'Written'
                AppliedCorrections = @($Correction)
                WriteResult = $WriteResult
            } -Report @{
                AnalysisSource = 'Candidate'
                EffectiveText = '$Value = 2'
                EffectiveFindings = @($Finding)
                FindingsWithAppliedCorrections = @($Finding)
                FindingsWithAcceptedCorrections = @($Finding)
            }

        $Result.Path | Should -Be 'Example.ps1'
        [object]::ReferenceEquals($Result.Proposal, $Proposal) | Should -BeTrue

        $Result.Application.Status | Should -Be 'Written'
        $Result.Application.AppliedCorrections[0] | Should -Be $Correction
        $Result.Application.WriteResult | Should -Be $WriteResult
        $Result.Application.ErrorRecord | Should -BeNullOrEmpty

        $Result.Report.AnalysisSource | Should -Be 'Candidate'
        $Result.Report.EffectiveText | Should -Be '$Value = 2'
        $Result.Report.EffectiveFindings[0] | Should -Be $Finding
        $Result.Report.FindingsWithAppliedCorrections[0] | Should -Be $Finding
        $Result.Report.FindingsWithAcceptedCorrections[0] | Should -Be $Finding
    }

    It 'rejects a result passed as a proposal during parameter binding' {
        $Result = New-NitpickCorrectionResult

        { New-NitpickCorrectionResult -Proposal $Result -ErrorAction Stop } |
            Should -Throw '*NitpickCorrectionProposal*'
    }

    It 'rejects invalid collection element types' {
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ AppliedCorrections = @('not a correction') } -ErrorAction Stop } |
            Should -Throw '*NitpickCorrection*'
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Report @{ AnalysisSource = 'Original'; EffectiveFindings = @('not a finding') } -ErrorAction Stop } |
            Should -Throw '*NitpickFinding*'
    }

    It 'normalizes zero and single supplied collections to arrays' -ForEach @(
        @{ Single = $false; Count = 0 }
        @{ Single = $true; Count = 1 }
    ) {
        $Corrections = if ($Single) { $Correction } else { @() }
        $Findings = if ($Single) { $Finding } else { @() }
        $Result = New-NitpickCorrectionResult `
            -Proposal $Proposal `
            -Application @{ Status = 'Written'; WriteResult = $WriteResult; AppliedCorrections = $Corrections } `
            -Report @{
                AnalysisSource = 'Candidate'
                EffectiveFindings = $Findings
                FindingsWithAppliedCorrections = $Findings
                FindingsWithAcceptedCorrections = $Findings
            }

        $Result.Application.AppliedCorrections -is [array] | Should -BeTrue
        $Result.Application.AppliedCorrections | Should -HaveCount $Count

        foreach ($Property in @('EffectiveFindings', 'FindingsWithAppliedCorrections', 'FindingsWithAcceptedCorrections')) {
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

    It 'rejects applied corrections under <Status>' -ForEach @(
        @{ Status = 'NotAttempted' }
        @{ Status = 'Preview' }
        @{ Status = 'WhatIf' }
        @{ Status = 'Declined' }
        @{ Status = 'FailedValidation' }
        @{ Status = 'StaleSource' }
        @{ Status = 'StaleTarget' }
        @{ Status = 'InvalidTarget' }
        @{ Status = 'FailedWrite' }
    ) {
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ Status = $Status; AppliedCorrections = @($Correction) } } |
            Should -Throw '*require a Written or InMemory application*'
    }

    It 'accepts applied corrections for an in-memory application' {
        $Result = New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ Status = 'InMemory'; AppliedCorrections = @($Correction) } `
            -Report @{
                AnalysisSource = 'Candidate'
                FindingsWithAppliedCorrections = @($Finding)
                FindingsWithAcceptedCorrections = @($Finding)
            }

        $Result.Application.Status | Should -Be 'InMemory'
        $Result.Application.AppliedCorrections[0] | Should -Be $Correction
        $Result.Report.FindingsWithAppliedCorrections[0] | Should -Be $Finding
    }

    It 'accepts accepted-correction attribution without an application for Preview' {
        $Result = New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ Status = 'Preview' } `
            -Report @{ AnalysisSource = 'Candidate'; FindingsWithAcceptedCorrections = @($Finding) }

        $Result.Report.FindingsWithAcceptedCorrections[0] | Should -Be $Finding
        $Result.Application.AppliedCorrections | Should -HaveCount 0
    }

    It 'rejects attributed findings without an applying application' {
        { New-NitpickCorrectionResult -Proposal $Proposal -Report @{
            AnalysisSource = 'Original'
            FindingsWithAppliedCorrections = @($Finding)
        } } | Should -Throw '*require a Written or InMemory application*'
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

    It 'rejects applying a correction outside the accepted proposal under <Status>' -ForEach @(
        @{ Status = 'Written' }
        @{ Status = 'InMemory' }
    ) {
        $OtherCorrection = New-NitpickCorrection -ViolationExtent $Extent -ReplacementText '$Value = 3' `
            -FilePathOrContext '<ScriptBlock>' -Description 'Unrelated edit'
        $Application = @{ Status = $Status; AppliedCorrections = @($OtherCorrection) }
        if ($Status -eq 'Written') { $Application.WriteResult = $WriteResult }
        { New-NitpickCorrectionResult -Proposal $Proposal -Application $Application } |
            Should -Throw '*proposal accepted corrections*'
    }

    It 'requires a Ready proposal for Written' {
        $Proposal.Status = 'Rejected'
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Application @{ Status = 'Written'; WriteResult = $WriteResult } } |
            Should -Throw '*Ready proposal*'
    }

    It 'rejects attributing findings when no corrections were applied under <Status>' -ForEach @(
        @{ Status = 'Written' }
        @{ Status = 'InMemory' }
    ) {
        $Application = @{ Status = $Status }
        if ($Status -eq 'Written') { $Application.WriteResult = $WriteResult }
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Application $Application `
            -Report @{ AnalysisSource = 'Original'; FindingsWithAppliedCorrections = @($Finding) } } |
            Should -Throw '*none were applied*'
    }

    It 'rejects attributing findings to accepted corrections when none were accepted' {
        $Proposal.AcceptedCorrections = @()
        { New-NitpickCorrectionResult -Proposal $Proposal `
            -Report @{ AnalysisSource = 'Original'; FindingsWithAcceptedCorrections = @($Finding) } } |
            Should -Throw '*none were accepted*'
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
        @{ Property = 'EffectiveFindings'; Value = $null }
        @{ Property = 'FindingsWithAppliedCorrections'; Value = $null }
        @{ Property = 'FindingsWithAcceptedCorrections'; Value = $null }
    ) {
        $Content = if ($Property -eq 'EffectiveText') { $Value } else { @($Finding) }
        { New-NitpickCorrectionResult -Report @{ $Property = $Content } } |
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

        $First.Application.AppliedCorrections += $Correction
        $First.Application.Status = 'Written'
        $First.Report.EffectiveFindings += $Finding
        $First.Report.AnalysisSource = 'Candidate'

        $Second.Application.AppliedCorrections | Should -HaveCount 0
        $Second.Application.Status | Should -Be 'NotAttempted'
        $Second.Report.EffectiveFindings | Should -HaveCount 0
        $Second.Report.AnalysisSource | Should -Be 'None'
    }
}
