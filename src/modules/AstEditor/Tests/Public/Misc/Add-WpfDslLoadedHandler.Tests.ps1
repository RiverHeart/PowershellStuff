using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
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

        $Document = New-AstDocument -InputObject $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -HandlerBody "Write-Verbose 'Loaded handler from AstOverlayLab.'"
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

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

        $Document = New-AstDocument -InputObject $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler Skip
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

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

        $Document = New-AstDocument -InputObject $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler InsertAfterExisting -HandlerBody "Write-Verbose 'forced AstOverlayLab insertion'"
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

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

        $Document = New-AstDocument -InputObject $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler AppendToExistingBody -HandlerBody "Write-Verbose 'appended AstOverlayLab code'"
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

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

        $Document = New-AstDocument -InputObject $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -Force -HandlerBody "Write-Verbose 'forced compatibility AstOverlayLab insertion'"
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Changed | Should -BeTrue
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 1
        $Validation.RenderedText | Should -Match 'forced compatibility AstOverlayLab insertion'
    }

    It 'is idempotent for InsertAfterExisting when identical body already exists' {
        $Source = @"
Window Main {
    When 'Loaded' {
        Write-Verbose 'already there'
    }
    When 'Loaded' {
        Write-Verbose 'idempotent AstOverlayLab insertion'
    }
}
"@

        $Document = New-AstDocument -InputObject $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler InsertAfterExisting -HandlerBody "Write-Verbose 'idempotent AstOverlayLab insertion'"
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Changed | Should -BeFalse
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 0
        $Validation.RenderedText | Should -Be $Source
    }

    It 'does not treat a matching comment as an existing handler body' {
        $Source = @"
Window Main {
    When 'Loaded' {
        # Write-Verbose 'commented AstOverlayLab insertion'
        Write-Verbose 'already there'
    }
}
"@

        $Document = New-AstDocument -InputObject $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler InsertAfterExisting -HandlerBody "Write-Verbose 'commented AstOverlayLab insertion'"
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Changed | Should -BeTrue
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 1
        $Validation.RenderedText | Should -Match 'commented AstOverlayLab insertion'

        $MatchCount = ([regex]::Matches($Validation.RenderedText, 'When ''Loaded''')).Count
        $MatchCount | Should -Be 2
    }

    It 'can still insert duplicate bodies when AllowDuplicateHandlerBody is set' {
        $Source = @"
Window Main {
    When 'Loaded' {
        Write-Verbose 'already there'
    }
    When 'Loaded' {
        Write-Verbose 'duplicate AstOverlayLab insertion'
    }
}
"@

        $Document = New-AstDocument -InputObject $Source
        $Changed = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler InsertAfterExisting -AllowDuplicateHandlerBody -HandlerBody "Write-Verbose 'duplicate AstOverlayLab insertion'"
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Changed | Should -BeTrue
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 1

        $MatchCount = ([regex]::Matches($Validation.RenderedText, 'duplicate AstOverlayLab insertion')).Count
        $MatchCount | Should -Be 2
    }
}

Describe 'WPF Loaded-handler rewrite plan MVP' {
    It 'builds an InsertMissingHandler plan and emits one edit' {
        InModuleScope AstEditor {
            $Source = @"
Window Main {
    StackPanel {
        TextBlock 'Hello'
    }
}
"@

            $Document = New-AstDocument -InputObject $Source
            $Plan = New-WpfDslLoadedHandlerRewritePlan -Document $Document -HandlerBody "Write-Verbose 'plan AstOverlayLab insertion'"
            $Changed = Invoke-WpfDslLoadedHandlerRewritePlan -Document $Document -Plan $Plan
            $Validation = Resolve-AstDocument -Document $Document -PassThruText

            $Plan.Action | Should -Be 'InsertMissingHandler'
            $Changed | Should -BeTrue
            $Validation.EditCount | Should -Be 1
            $Validation.ParseErrorCount | Should -Be 0
            $Validation.RenderedText | Should -Match 'plan AstOverlayLab insertion'
        }
    }

    It 'builds a None plan when identical Loaded body already exists' {
        InModuleScope AstEditor {
            $Source = @"
Window Main {
    When 'Loaded' {
        Write-Verbose 'already planned'
    }
}
"@

            $Document = New-AstDocument -InputObject $Source
            $Plan = New-WpfDslLoadedHandlerRewritePlan -Document $Document -HandlerBody "Write-Verbose 'already planned'"
            $Changed = Invoke-WpfDslLoadedHandlerRewritePlan -Document $Document -Plan $Plan
            $Validation = Resolve-AstDocument -Document $Document -PassThruText

            $Plan.Action | Should -Be 'None'
            $Plan.HandlerBodyAlreadyPresent | Should -BeTrue
            $Changed | Should -BeFalse
            $Validation.EditCount | Should -Be 0
            $Validation.ParseErrorCount | Should -Be 0
        }
    }
}
