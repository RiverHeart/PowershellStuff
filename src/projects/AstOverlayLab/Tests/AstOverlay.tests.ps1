$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/../AstOverlay.ps1"
}

Describe 'Add-WpfDslLoadedHandler' {
    It 'inserts a Loaded handler when one is missing' {
        $Source = @"
Window Main {
    StackPanel {
        TextBlock 'Hello'
    }
}
"@

        $Document = New-AstOverlay -Text $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -HandlerBody "Write-Verbose 'Loaded handler from AstOverlayLab.'"
        $Validation = Test-AstOverlay -Document $Document -PassThruText

        $Changed | Should -BeTrue
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 1
        $Validation.RenderedText | Should -Match "When 'Loaded'"
        $Validation.RenderedText | Should -Match 'AstOverlayLab'
    }

    It 'does not insert a duplicate Loaded handler when policy is Skip' {
        $Source = @"
Window Main {
    When 'Loaded' {
        Write-Verbose 'already there'
    }
}
"@

        $Document = New-AstOverlay -Text $Source
    $Changed = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler Skip
        $Validation = Test-AstOverlay -Document $Document -PassThruText

        $Changed | Should -BeFalse
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 0
        $Validation.RenderedText | Should -Be $Source
    }

    It 'inserts directly after an existing handler when policy is InsertAfterExisting' {
        $Source = @"
Window Main {
    When 'Loaded' {
        Write-Verbose 'already there'
    }
}
"@

        $Document = New-AstOverlay -Text $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler InsertAfterExisting -HandlerBody "Write-Verbose 'forced AstOverlayLab insertion'"
        $Validation = Test-AstOverlay -Document $Document -PassThruText

        $Changed | Should -BeTrue
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 1
        $Validation.RenderedText | Should -Match 'forced AstOverlayLab insertion'

        $ExistingIndex = $Validation.RenderedText.IndexOf("Write-Verbose 'already there'")
        $InsertedIndex = $Validation.RenderedText.IndexOf("Write-Verbose 'forced AstOverlayLab insertion'")
        $InsertedIndex | Should -BeGreaterThan $ExistingIndex
    }

    It 'appends to existing handler body when policy is AppendToExistingBody' {
        $Source = @"
Window Main {
    When 'Loaded' {
        Write-Verbose 'already there'
    }
}
"@

        $Document = New-AstOverlay -Text $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler AppendToExistingBody -HandlerBody "Write-Verbose 'appended AstOverlayLab code'"
        $Validation = Test-AstOverlay -Document $Document -PassThruText

        $Changed | Should -BeTrue
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 1
        $Validation.RenderedText | Should -Match "Write-Verbose 'already there'"
        $Validation.RenderedText | Should -Match "Write-Verbose 'appended AstOverlayLab code'"

        $WhenCount = ([regex]::Matches($Validation.RenderedText, "When 'Loaded'")).Count
        $WhenCount | Should -Be 1
    }

    It 'keeps Force backward compatibility by inserting after existing handler when policy is not set' {
        $Source = @"
Window Main {
    When 'Loaded' {
        Write-Verbose 'already there'
    }
}
"@

        $Document = New-AstOverlay -Text $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -Force -HandlerBody "Write-Verbose 'forced compatibility AstOverlayLab insertion'"
        $Validation = Test-AstOverlay -Document $Document -PassThruText

        $Changed | Should -BeTrue
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 1
        $Validation.RenderedText | Should -Match 'forced compatibility AstOverlayLab insertion'
    }
}
