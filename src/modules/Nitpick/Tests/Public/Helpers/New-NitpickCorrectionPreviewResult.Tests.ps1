BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
    $CollectionProperties = @(
        'OriginalFindings', 'FinalFindings', 'CandidateFindings', 'RemainingFindings',
        'AcceptedCorrections', 'FixedCorrections', 'FixedFindings', 'SkippedFindings',
        'ConflictedFindings', 'FailedValidationFindings', 'SkippedCorrections',
        'Conflicts', 'ParseErrors'
    )
    $DiagnosticProperties = @(
        'OriginalFingerprint', 'Document', 'WriteResult', 'CandidateText',
        'RenderedText', 'Diff', 'ErrorRecord'
    )
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickCorrectionPreviewResult' {
    It 'exports the factory and declares its output type' {
        $Command = Get-Command New-NitpickCorrectionPreviewResult -Module Nitpick

        $Command.OutputType.Name | Should -Contain 'Nitpick.CorrectionPreviewResult'
    }

    It 'creates the complete schema with empty collections and null diagnostics' {
        $Result = New-NitpickCorrectionPreviewResult
        $ExpectedProperties = @(
            'Path', 'WriteStatus', 'WasWritten', 'WasReanalyzed'
        ) + $CollectionProperties + $DiagnosticProperties

        $Result.PSTypeNames[0] | Should -Be 'Nitpick.CorrectionPreviewResult'
        $Result.PSObject.Properties.Name | Should -HaveCount $ExpectedProperties.Count
        foreach ($Property in $ExpectedProperties) {
            $Result.PSObject.Properties.Name | Should -Contain $Property
        }
        $Result.Path | Should -Be '<ScriptBlock>'
        $Result.WriteStatus | Should -Be 'Preview'
        $Result.WasWritten | Should -BeFalse
        $Result.WasReanalyzed | Should -BeFalse
        foreach ($Property in $CollectionProperties) {
            ($Result.$Property -is [array]) | Should -BeTrue
            $Result.$Property.Count | Should -Be 0
        }
        foreach ($Property in $DiagnosticProperties) {
            ($null -eq $Result.$Property) | Should -BeTrue
        }
    }

    It 'retains supplied values for every result property' {
        $Parameters = @{
            Path = 'Example.ps1'
            WriteStatus = 'Written'
            OriginalFingerprint = 'fingerprint'
            Document = [pscustomobject]@{ Name = 'Document' }
            WriteResult = [pscustomobject]@{ WasWritten = $true }
            WasWritten = $true
            WasReanalyzed = $true
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
        foreach ($Property in $CollectionProperties) {
            $Parameters[$Property] = @([pscustomobject]@{ Name = $Property })
        }

        $Result = New-NitpickCorrectionPreviewResult @Parameters

        foreach ($Property in $Parameters.Keys) {
            if ($Property -in $CollectionProperties) {
                ($Result.$Property -is [array]) | Should -BeTrue
                $Result.$Property | Should -HaveCount 1
                $Result.$Property[0] | Should -Be $Parameters[$Property][0]
            } else {
                $Result.$Property | Should -Be $Parameters[$Property]
            }
        }
    }

    It 'preserves empty rendered source and a null in-memory fingerprint' {
        $Result = New-NitpickCorrectionPreviewResult `
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
        $First = New-NitpickCorrectionPreviewResult
        $Second = New-NitpickCorrectionPreviewResult

        $First.FixedFindings += 'fixed'
        $First.WriteStatus = 'Written'

        $Second.FixedFindings.Count | Should -Be 0
        $Second.WriteStatus | Should -Be 'Preview'
    }
}
