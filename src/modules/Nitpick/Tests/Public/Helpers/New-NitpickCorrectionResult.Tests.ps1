BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
    $TopLevelProperties = @(
        'Path', 'WriteStatus', 'WasWritten', 'WasReanalyzed', 'OriginalFingerprint',
        'Document', 'WriteResult', 'Findings', 'Corrections', 'ParseErrors',
        'CandidateText', 'RenderedText', 'Diff', 'ErrorRecord'
    )
    $FindingsProperties = @(
        'Original', 'Candidate', 'Final', 'Remaining', 'Fixed', 'Skipped',
        'Conflicted', 'FailedValidation'
    )
    $CorrectionsProperties = @('Accepted', 'Fixed', 'Skipped', 'Conflicts')
    $DiagnosticProperties = @(
        'OriginalFingerprint', 'Document', 'WriteResult', 'CandidateText',
        'RenderedText', 'Diff', 'ErrorRecord'
    )
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickCorrectionResult' {
    It 'exports the factory and declares its output type' {
        $Command = Get-Command New-NitpickCorrectionResult -Module Nitpick

        $Command.OutputType.Name | Should -Contain 'Nitpick.CorrectionResult'
    }

    It 'creates the complete schema with empty collections and null diagnostics' {
        $Result = New-NitpickCorrectionResult

        $Result.PSTypeNames[0] | Should -Be 'Nitpick.CorrectionResult'
        $Result.PSObject.Properties.Name | Should -HaveCount $TopLevelProperties.Count
        foreach ($Property in $TopLevelProperties) {
            $Result.PSObject.Properties.Name | Should -Contain $Property
        }
        $Result.Path | Should -Be '<ScriptBlock>'
        $Result.WriteStatus | Should -Be 'Preview'
        $Result.WasWritten | Should -BeFalse
        $Result.WasReanalyzed | Should -BeFalse
        $Result.Findings.PSObject.Properties.Name | Should -HaveCount $FindingsProperties.Count
        $Result.Corrections.PSObject.Properties.Name | Should -HaveCount $CorrectionsProperties.Count
        foreach ($Property in $FindingsProperties) {
            ($Result.Findings.$Property -is [array]) | Should -BeTrue
            $Result.Findings.$Property.Count | Should -Be 0
        }
        foreach ($Property in $CorrectionsProperties) {
            ($Result.Corrections.$Property -is [array]) | Should -BeTrue
            $Result.Corrections.$Property.Count | Should -Be 0
        }
        ($Result.ParseErrors -is [array]) | Should -BeTrue
        $Result.ParseErrors.Count | Should -Be 0
        foreach ($Property in $DiagnosticProperties) {
            ($null -eq $Result.$Property) | Should -BeTrue
        }
    }

    It 'retains supplied values for every top-level result property' {
        $Parameters = @{
            Path = 'Example.ps1'
            WriteStatus = 'Written'
            OriginalFingerprint = 'fingerprint'
            Document = [pscustomobject]@{ Name = 'Document' }
            WriteResult = [pscustomobject]@{ WasWritten = $true }
            WasWritten = $true
            WasReanalyzed = $true
            ParseErrors = @([pscustomobject]@{ Name = 'ParseErrors' })
            CandidateText = '$Value = 2'
            RenderedText = '$Value = 2'
            Diff = 'diff'
            ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.IO.IOException]::new('Read failed.'),
                'ReadFailure',
                [System.Management.Automation.ErrorCategory]::ReadError,
                'Example.ps1'
            )
        }

        $Result = New-NitpickCorrectionResult @Parameters

        foreach ($Property in $Parameters.Keys) {
            if ($Property -eq 'ParseErrors') {
                $Result.ParseErrors | Should -HaveCount 1
                $Result.ParseErrors[0] | Should -Be $Parameters.ParseErrors[0]
            } else {
                $Result.$Property | Should -Be $Parameters[$Property]
            }
        }
    }

    It 'retains supplied values for Findings and Corrections subgroups' {
        $Findings = @{}
        foreach ($Property in $FindingsProperties) {
            $Findings[$Property] = @([pscustomobject]@{ Name = $Property })
        }
        $Corrections = @{}
        foreach ($Property in $CorrectionsProperties) {
            $Corrections[$Property] = @([pscustomobject]@{ Name = $Property })
        }

        $Result = New-NitpickCorrectionResult -Findings $Findings -Corrections $Corrections

        foreach ($Property in $FindingsProperties) {
            $Result.Findings.$Property | Should -HaveCount 1
            $Result.Findings.$Property[0] | Should -Be $Findings[$Property][0]
        }
        foreach ($Property in $CorrectionsProperties) {
            $Result.Corrections.$Property | Should -HaveCount 1
            $Result.Corrections.$Property[0] | Should -Be $Corrections[$Property][0]
        }
    }

    It 'defaults unspecified Findings and Corrections keys to an empty array' {
        $Result = New-NitpickCorrectionResult -Findings @{ Fixed = @('fixed') }

        $Result.Findings.Fixed | Should -HaveCount 1
        $Result.Findings.Original.Count | Should -Be 0
        $Result.Corrections.Accepted.Count | Should -Be 0
    }

    It 'preserves empty rendered source and a null in-memory fingerprint' {
        $Result = New-NitpickCorrectionResult `
            -OriginalFingerprint $null `
            -CandidateText '' `
            -RenderedText '' `
            -Diff ''

        ($null -eq $Result.OriginalFingerprint) | Should -BeTrue
        ($null -eq $Result.CandidateText) | Should -BeFalse
        $Result.CandidateText | Should -BeExactly ''
        $Result.RenderedText | Should -BeExactly ''
        $Result.Diff | Should -BeExactly ''
    }

    It 'does not share mutable result state between instances' {
        $First = New-NitpickCorrectionResult
        $Second = New-NitpickCorrectionResult

        $First.Findings.Fixed += 'fixed'
        $First.WriteStatus = 'Written'

        $Second.Findings.Fixed.Count | Should -Be 0
        $Second.WriteStatus | Should -Be 'Preview'
    }
}
