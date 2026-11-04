BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../Nitpick.psd1') -Force
    . (Join-Path $PSScriptRoot '../Support/CorrectionFixtures.ps1')

    function Invoke-GuidedSelection {
        param ($Fixture, $Finding)

        InModuleScope Nitpick -Parameters @{ Fixture = $Fixture; Finding = $Finding } {
            param($Fixture, $Finding)
            Select-NitpickGuidedCorrection `
                -Finding $Finding `
                -Correction $Finding.Corrections `
                -Document $Fixture.Document
        }
    }
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Select-NitpickGuidedCorrection' {
    BeforeEach {
        $Editor = New-TestPSEditor
        $EditorState = Set-TestPSEditor -Editor $Editor

        $Answers = [System.Collections.Generic.Queue[object]]::new()
        Mock Read-Host -ModuleName Nitpick { $Answers.Dequeue() }
        Mock Write-Host -ModuleName Nitpick { }
    }

    AfterEach {
        Restore-TestPSEditor -State $EditorState
    }

    It 'selects the violation range of a <Kind> document in one-based source coordinates' -ForEach @(
        @{ Kind = 'File' }
        @{ Kind = 'Nested' }
    ) {
        $Fixture = New-TestSourceDocument -Kind $Kind
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Unsafe'
        $Original = Get-TestSourceExtent -Fixture $Fixture -Finding $Finding
        $Answers.Enqueue('0')

        $Chosen = Invoke-GuidedSelection $Fixture $Finding

        [object]::ReferenceEquals($Chosen, $Finding.Corrections[0]) | Should -BeTrue
        $Editor.Workspace.OpenedPaths | Should -Be @($Fixture.Path)
        $Editor.Context.Selections | Should -HaveCount 1
        ($Editor.Context.Selections[0] -join ',') | Should -Be (
            @($Original.StartLineNumber, $Original.StartColumnNumber, $Original.EndLineNumber, $Original.EndColumnNumber) -join ','
        )
        $Fixture.Document.IsFileBacked | Should -Be ($Kind -eq 'File')
    }

    It 'does not navigate without <Label> but still prompts' -ForEach @(
        @{ Label = 'source provenance'; Kind = 'String'; HasEditor = $true }
        @{ Label = 'Editor Services'; Kind = 'File'; HasEditor = $false }
    ) {
        $Fixture = New-TestSourceDocument -Kind $Kind
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Unsafe'
        if (-not $HasEditor) {
            $null = Set-TestPSEditor -Editor $null
        }
        $Answers.Enqueue('1')

        $Chosen = Invoke-GuidedSelection $Fixture $Finding

        [object]::ReferenceEquals($Chosen, $Finding.Corrections[1]) | Should -BeTrue
        $Editor.Workspace.OpenedPaths | Should -HaveCount 0
        $Editor.Context.Selections | Should -HaveCount 0
        Should -Invoke Read-Host -ModuleName Nitpick -Times 1 -Exactly
    }

    It 'warns and still prompts when navigation fails' {
        $null = Set-TestPSEditor -Editor (New-TestPSEditor -OpenFileThrows 'editor unavailable')
        $Fixture = New-TestSourceDocument
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Unsafe'
        $Answers.Enqueue('0')

        $WarningMessages = @(InModuleScope Nitpick -Parameters @{ Fixture = $Fixture; Finding = $Finding } {
            param($Fixture, $Finding)
            $null = Select-NitpickGuidedCorrection `
                -Finding $Finding `
                -Correction $Finding.Corrections `
                -Document $Fixture.Document `
                -WarningVariable Warnings 3>$null
            @($Warnings | ForEach-Object { $_.Message })
        })

        $WarningMessages | Should -HaveCount 1
        $WarningMessages[0] | Should -Match 'Could not navigate.*editor unavailable'
        Should -Invoke Read-Host -ModuleName Nitpick -Times 1 -Exactly
    }

    It 'lists non-Safe applicability in the prompt' {
        $Fixture = New-TestSourceDocument
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Unsafe'
        $Answers.Enqueue('0')

        $null = Invoke-GuidedSelection $Fixture $Finding

        Should -Invoke Write-Host -ModuleName Nitpick -ParameterFilter { $Object -like '*`[0`] Safe alternative 0' } -Times 1
        Should -Invoke Write-Host -ModuleName Nitpick -ParameterFilter { $Object -like '*`[1`] (Unsafe) Unsafe alternative 1' } -Times 1
    }

    It 'rejects out-of-range and non-numeric answers until a valid index is entered' {
        $Fixture = New-TestSourceDocument
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Unsafe'
        foreach ($Answer in '20', '1x', '-1', '2', ' 1') {
            $Answers.Enqueue($Answer)
        }

        $Chosen = Invoke-GuidedSelection $Fixture $Finding

        [object]::ReferenceEquals($Chosen, $Finding.Corrections[1]) | Should -BeTrue
        Should -Invoke Read-Host -ModuleName Nitpick -Times 5 -Exactly
    }

    It 'returns nothing on a <Label> answer instead of looping' -ForEach @(
        @{ Label = 'blank'; Answer = '' }
        @{ Label = 'whitespace'; Answer = '   ' }
        @{ Label = 'null (end of input)'; Answer = $null }
    ) {
        $Fixture = New-TestSourceDocument
        $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Unsafe'
        $Answers.Enqueue($Answer)

        $Chosen = Invoke-GuidedSelection $Fixture $Finding

        $Chosen | Should -BeNullOrEmpty
        Should -Invoke Read-Host -ModuleName Nitpick -Times 1 -Exactly
    }
}
