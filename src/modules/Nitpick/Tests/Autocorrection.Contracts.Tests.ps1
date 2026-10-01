using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'

BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name "$PSScriptRoot/../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Nitpick autocorrection contracts' -Tag 'AutocorrectionContract' {
    It 'preserves one-based line and column coordinates for ScriptAnalyzer' {
        $Source = "`$First = 1`n`$Second = 2"
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $Errors)
        $Extent = $Ast.EndBlock.Statements[1].Extent

        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Second = 3' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the second assignment.'

        $Correction.StartLineNumber | Should -Be 2
        $Correction.StartColumnNumber | Should -Be 1
        $Correction.EndLineNumber | Should -Be 2
        $Correction.EndColumnNumber | Should -Be 12
    }

    It 'converts native coordinates and replacement text without changing them' {
        $Correction = New-NitpickCorrection `
            -StartLineNumber 2 `
            -EndLineNumber 3 `
            -StartColumnNumber 4 `
            -EndColumnNumber 5 `
            -ReplacementText "first`nsecond" `
            -FilePathOrContext 'Example.ps1' `
            -Description 'Replace a multiline range.' `
            -OutputAs CorrectionExtent

        $Correction.StartLineNumber | Should -Be 2
        $Correction.EndLineNumber | Should -Be 3
        $Correction.StartColumnNumber | Should -Be 4
        $Correction.EndColumnNumber | Should -Be 5
        $Correction.Text | Should -Be "first`nsecond"
        $Correction.File | Should -Be 'Example.ps1'
    }

    It 'keeps file-backed and in-memory correction provenance explicit' {
        $Path = Join-Path $TestDrive 'Source.ps1'
        Set-Content -LiteralPath $Path -Value '$Value = 1' -NoNewline
        $FileAst = Import-ScriptBlockAst -FilePath $Path
        $FileExtent = $FileAst.EndBlock.Statements[0].Extent
        $MemoryExtent = { $Value = 1 }.Ast.EndBlock.Statements[0].Extent

        $FileCorrection = New-NitpickCorrection `
            -ViolationExtent $FileExtent `
            -ReplacementText '$Value = 2' `
            -FilePathOrContext $FileExtent.File `
            -Description 'Replace a file-backed assignment.'
        $MemoryCorrection = New-NitpickCorrection `
            -ViolationExtent $MemoryExtent `
            -ReplacementText '$Value = 2' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace an in-memory assignment.'

        $FileCorrection.FilePathOrContext | Should -Be (Resolve-Path -LiteralPath $Path).Path
        $MemoryCorrection.FilePathOrContext | Should -Be '<ScriptBlock>'
    }

    It 'does not expose file mutation on an individual correction' {
        $Extent = { $Value = 1 }.Ast.EndBlock.Statements[0].Extent
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Value = 2' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the assignment.'

        $Correction.PSObject.Methods.Name | Should -Not -Contain 'Fix'
    }

    It 'captures zero-based half-open offsets and expected text from an extent' -Skip {
        throw 'Phase 2 must add native offset and expected-text metadata.'
    }

    It 'applies only Safe corrections by default' -Skip {
        throw 'Phase 2 must add applicability and Phase 3 must enforce it.'
    }

    It 'accepts or rejects every correction in an atomic group together' -Skip {
        throw 'Phase 3 must implement correction-group transactions.'
    }

    It 'rejects the complete target batch when independent groups overlap' -Skip {
        throw 'Phase 3 must implement the initial target-level conflict policy.'
    }

    It 'keeps preview mode from changing file-backed targets' -Skip {
        throw 'Phase 3 must add the preview-only correction coordinator.'
    }

    It 'returns rendered text instead of writing for in-memory targets' -Skip {
        throw 'Phase 3 must define explicit in-memory preview output.'
    }

    It 'reports findings and severity counts from final analysis after fixing' -Skip {
        throw 'Phase 4 must integrate final analysis with Start-Nitpicking.'
    }

    It 'isolates a failed target without partially applying other target transactions' -Skip {
        throw 'Phase 4 must implement multi-target failure isolation.'
    }
}
