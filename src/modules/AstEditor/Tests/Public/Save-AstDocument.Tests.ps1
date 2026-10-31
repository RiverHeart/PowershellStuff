BeforeAll {
    Import-Module "$PSScriptRoot\..\..\AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module AstEditor -Force -ErrorAction SilentlyContinue
}

BeforeDiscovery {
    $EncodingCases = foreach ($NewLine in "`r`n", "`n") {
        foreach ($EncodingName in 'Utf8', 'Utf8Bom', 'Utf16LE', 'Utf16BE', 'Utf32LE', 'Utf32BE') {
            @{ EncodingName = $EncodingName; NewLine = $NewLine }
        }
    }
}

Describe 'Save-AstDocument transactions' {
    It 'preserves <EncodingName> bytes, BOM, Unicode, and newline style' -ForEach $EncodingCases {
        $Encoding = switch ($EncodingName) {
            Utf8 { [System.Text.UTF8Encoding]::new($false, $true) }
            Utf8Bom { [System.Text.UTF8Encoding]::new($true, $true) }
            Utf16LE { [System.Text.UnicodeEncoding]::new($false, $true, $true) }
            Utf16BE { [System.Text.UnicodeEncoding]::new($true, $true, $true) }
            Utf32LE { [System.Text.UTF32Encoding]::new($false, $true, $true) }
            Utf32BE { [System.Text.UTF32Encoding]::new($true, $true, $true) }
        }
        $Path = Join-Path $TestDrive "$EncodingName.ps1"
        $Source = "# $([char]0x00E9)$NewLine`$Value = 1$NewLine"
        $Expected = "# $([char]0x00E9)$NewLine`$Value = 2$NewLine"
        [System.IO.File]::WriteAllText($Path, $Source, $Encoding)
        $Document = New-AstDocument -Path $Path
        $Offset = $Source.LastIndexOf('1')
        $null = Add-AstTextEdit -Document $Document -StartOffset $Offset -EndOffset ($Offset + 1) `
            -ReplacementText '2' -Reason 'Replace value'

        $Result = Save-AstDocument -Document $Document -Confirm:$false

        $Result.WasWritten | Should -BeTrue
        $Result.WriteStatus | Should -Be 'Written'
        $Result.ErrorRecord | Should -BeNullOrEmpty
        $ActualBytes = [System.IO.File]::ReadAllBytes($Path)
        $ExpectedBytes = [byte[]](@($Encoding.GetPreamble()) + @($Encoding.GetBytes($Expected)))
        [Convert]::ToBase64String($ActualBytes) | Should -Be ([Convert]::ToBase64String($ExpectedBytes))
        @(Get-ChildItem $TestDrive -Filter '*.tmp' -Force) | Should -HaveCount 0
        $Document.Ast.Extent.File | Should -Be $Path
    }

    It 'returns WhatIf without changing source bytes or staging a file' {
        $Path = Join-Path $TestDrive 'WhatIf.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Document = New-AstDocument -Path $Path
        $null = Add-AstTextEdit -Document $Document -StartOffset 9 -EndOffset 10 `
            -ReplacementText '2' -Reason 'Replace value'

        $Result = Save-AstDocument -Document $Document -WhatIf

        $Result.WriteStatus | Should -Be 'WhatIf'
        $Result.WasWritten | Should -BeFalse
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
        @(Get-ChildItem $TestDrive -Filter '*.tmp' -Force) | Should -HaveCount 0
    }

    It 'rejects changed bytes even when decoded source text is identical' {
        $Path = Join-Path $TestDrive 'Stale.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1', [System.Text.UTF8Encoding]::new($false))
        $Document = New-AstDocument -Path $Path
        $null = Add-AstTextEdit -Document $Document -StartOffset 9 -EndOffset 10 `
            -ReplacementText '2' -Reason 'Replace value'
        [System.IO.File]::WriteAllText($Path, '$Value = 1', [System.Text.UTF8Encoding]::new($true))
        $Before = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))

        $Result = Save-AstDocument -Document $Document -Confirm:$false

        $Result.WriteStatus | Should -Be 'StaleSource'
        $Result.ErrorRecord | Should -Not -BeNullOrEmpty
        $Result.WasWritten | Should -BeFalse
        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) | Should -Be $Before
        @(Get-ChildItem $TestDrive -Filter '*.tmp' -Force) | Should -HaveCount 0
    }

    It 'does not recreate a source deleted after analysis' {
        $Path = Join-Path $TestDrive 'Deleted.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Document = New-AstDocument -Path $Path
        [System.IO.File]::Delete($Path)

        $Result = Save-AstDocument -Document $Document -Confirm:$false

        $Result.WriteStatus | Should -Be 'StaleSource'
        Test-Path -LiteralPath $Path | Should -BeFalse
        @(Get-ChildItem $TestDrive -Filter '*.tmp' -Force) | Should -HaveCount 0
    }

    It 'rejects invalid rendered text before creating a temporary file' {
        $Path = Join-Path $TestDrive 'Invalid.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Document = New-AstDocument -Path $Path
        $null = Add-AstTextEdit -Document $Document -StartOffset 9 -EndOffset 10 `
            -ReplacementText '(' -Reason 'Invalid replacement'

        $Result = Save-AstDocument -Document $Document -Confirm:$false

        $Result.WriteStatus | Should -Be 'FailedValidation'
        $Result.ParseErrors | Should -Not -BeNullOrEmpty
        $Result.ErrorRecord | Should -Not -BeNullOrEmpty
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
        @(Get-ChildItem $TestDrive -Filter '*.tmp' -Force) | Should -HaveCount 0
    }

    It 'preserves the original and cleans staging after replacement fails' {
        $Path = Join-Path $TestDrive 'Failed.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Document = New-AstDocument -Path $Path
        $null = Add-AstTextEdit -Document $Document -StartOffset 9 -EndOffset 10 `
            -ReplacementText '2' -Reason 'Replace value'

        Mock Invoke-AstFileReplacement -ModuleName AstEditor {
            throw [System.IO.IOException]::new('Simulated replacement failure.')
        }

        $Result = Save-AstDocument -Document $Document -Confirm:$false

        $Result.WriteStatus | Should -Be 'FailedWrite'
        $Result.ErrorRecord.Exception.Message | Should -Be 'Simulated replacement failure.'
        $Result.WasWritten | Should -BeFalse
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
        @(Get-ChildItem $TestDrive -Filter '*.tmp' -Force) | Should -HaveCount 0
    }

    It 'requires an explicit destination for in-memory documents' {
        $Document = New-AstDocument -InputObject '$Value = 1'

        $Result = Save-AstDocument -Document $Document

        $Result.WriteStatus | Should -Be 'InvalidTarget'
        $Result.ErrorRecord | Should -Not -BeNullOrEmpty
        $Result.WasWritten | Should -BeFalse
    }

    It 'saves in-memory output to a new explicit destination' {
        $Document = New-AstDocument -InputObject '$Value = 1'
        $Path = Join-Path $TestDrive 'New.ps1'

        $Result = Save-AstDocument -Document $Document -OutPath $Path -Confirm:$false

        $Result.WriteStatus | Should -Be 'Written'
        [System.IO.File]::ReadAllText($Path) | Should -Be '$Value = 1'
    }

    It 'rejects ambiguous legacy bytes rather than silently replacing characters' {
        $Path = Join-Path $TestDrive 'Legacy.ps1'
        [System.IO.File]::WriteAllBytes($Path, [byte[]](0x23, 0x20, 0xE9))

        { New-AstDocument -Path $Path } | Should -Throw '*legacy encodings are not inferred*'
    }
}
