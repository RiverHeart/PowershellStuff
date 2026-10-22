BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickCorrectionResult' {
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
        @($Result.PSObject.Properties.Name | Sort-Object) -join ',' |
            Should -Be 'Application,Path,Proposal,Report'
        $Result.Path | Should -Be '<ScriptBlock>'
        $Result.Proposal | Should -BeNullOrEmpty
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
        $Proposal = [pscustomobject]@{ PSTypeName = 'Nitpick.CorrectionProposal'; Status = 'Ready' }
        $Correction = [pscustomobject]@{ Description = 'Replace value' }
        $Finding = [pscustomobject]@{ Message = 'Original finding' }
        $WriteResult = [pscustomobject]@{ Status = 'Written'; WasWritten = $true }
        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.IO.IOException]::new('Write failed.'),
            'WriteFailure',
            [System.Management.Automation.ErrorCategory]::WriteError,
            'Example.ps1'
        )


        $Result = New-NitpickCorrectionResult -Path 'Example.ps1' -Proposal $Proposal `
            -Application @{
                Status = 'Written'
                CommittedCorrections = @($Correction)
                WriteResult = $WriteResult
                ErrorRecord = $ErrorRecord
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
        $Result.Application.ErrorRecord | Should -Be $ErrorRecord

        $Result.Report.AnalysisSource | Should -Be 'Candidate'
        $Result.Report.EffectiveText | Should -Be '$Value = 2'
        $Result.Report.EffectiveFindings[0] | Should -Be $Finding
        $Result.Report.FindingsWithCommittedCorrections[0] | Should -Be $Finding
    }

    It 'normalizes zero and single supplied collections to arrays' -ForEach @(
        @{ Items = @(); Count = 0 }
        @{ Items = 'single'; Count = 1 }
    ) {
        $Result = New-NitpickCorrectionResult -Proposal $null `
            -Application @{ CommittedCorrections = $Items } `
            -Report @{ EffectiveFindings = $Items; FindingsWithCommittedCorrections = $Items }

        $Result.Application.CommittedCorrections -is [array] | Should -BeTrue
        $Result.Application.CommittedCorrections | Should -HaveCount $Count

        foreach ($Property in @('EffectiveFindings', 'FindingsWithCommittedCorrections')) {
            $Result.Report.$Property -is [array] | Should -BeTrue
            $Result.Report.$Property | Should -HaveCount $Count
        }

        $Result.Application.Status | Should -Be 'NotAttempted'
        $Result.Report.AnalysisSource | Should -Be 'None'
    }

    It 'preserves empty effective source independently of a nullable proposal' {
        $Result = New-NitpickCorrectionResult -Proposal $null -Report @{ EffectiveText = '' }

        ($null -eq $Result.Report.EffectiveText) | Should -BeFalse
        $Result.Report.EffectiveText | Should -BeExactly ''
    }

    It 'rejects unknown application and report keys instead of creating compatibility groups' {
        { New-NitpickCorrectionResult -Application @{ Fixed = @() } } | Should -Throw
        { New-NitpickCorrectionResult -Report @{ Remaining = @() } } | Should -Throw
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
