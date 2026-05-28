$ErrorActionPreference = 'Stop'

BeforeAll {
    . "$PSScriptRoot/../AstOverlay.ps1"
}

Describe 'New-AstDocument' {
    It 'parses string input via InputObject' {
        $Overlay = New-AstDocument -InputObject 'Window Main { }'

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.OriginalText | Should -Be 'Window Main { }'
        $Overlay.Path | Should -Be '<memory>'
    }

    It 'wraps ScriptBlock input passed via InputObject' {
        $Overlay = New-AstDocument -InputObject { Window Main { } }

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.Ast | Should -Not -BeNullOrEmpty
        $Overlay.OriginalText | Should -Match 'Window Main'
    }

    It 'wraps Ast input passed via InputObject' {
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput("Window Main { }", [ref] $Tokens, [ref] $Errors)

        $Overlay = New-AstDocument -InputObject $Ast

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.Ast | Should -Be $Ast
        $Overlay.OriginalText | Should -Be 'Window Main { }'
    }

    It 'accepts pipeline input via InputObject' {
        $Overlay = 'Window Main { }' | New-AstDocument

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.OriginalText | Should -Be 'Window Main { }'
        $Overlay.Path | Should -Be '<memory>'
    }
}

Describe 'AstDocument line helpers' {
    It 'renders prepend, replace, and append edits in the expected order and indentation' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
                param($Node)
                $Node -is [System.Management.Automation.Language.CommandAst] -and
                $Node.GetCommandName() -eq 'Write-Host'
            }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "....testing, mic check..."', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')
        $Overlay.AppendLine($WriteHostCall, 'Write-Output "Welcome to the AstOverlayLab!"', 'Insert additional greeting after Write-Host')

        $Validation = Resolve-AstDocument -Document $Overlay -PassThruText
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 3
        $Validation.RenderedText | Should -Be @'
function Greet {
    param([string] $Name)
    Write-Output "....testing, mic check..."
    Write-Output "Hello, $Name!"
    Write-Output "Welcome to the AstOverlayLab!"
}
'@
    }
}

Describe 'Show-AstDiff' {
    It 'shows all queued edits in sorted order' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
                param($Node)
                $Node -is [System.Management.Automation.Language.CommandAst] -and
                $Node.GetCommandName() -eq 'Write-Host'
            }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "prepended"', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')
        $Overlay.AppendLine($WriteHostCall, 'Write-Output "appended"', 'Insert additional greeting after Write-Host')

        $Diff = Show-AstDiff -Document $Overlay

        $Diff | Should -Match '\[0\] Insert greeting before Write-Host'
        $Diff | Should -Match '\[1\] Replace Write-Host with Write-Output'
        $Diff | Should -Match '\[2\] Insert additional greeting after Write-Host'
        $Diff | Should -Match 'prepended'
        $Diff | Should -Match 'appended'
    }

    It 'shows only selected edit indexes' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
                param($Node)
                $Node -is [System.Management.Automation.Language.CommandAst] -and
                $Node.GetCommandName() -eq 'Write-Host'
            }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "prepended"', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')
        $Overlay.AppendLine($WriteHostCall, 'Write-Output "appended"', 'Insert additional greeting after Write-Host')

        $Diff = Show-AstDiff -Document $Overlay -EditIndex 1

        $Diff | Should -Match '\[1\] Replace Write-Host with Write-Output'
        $Diff | Should -Not -Match '\[0\] Insert greeting before Write-Host'
        $Diff | Should -Not -Match '\[2\] Insert additional greeting after Write-Host'
    }

    It 'allows selecting the first edit index' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
                param($Node)
                $Node -is [System.Management.Automation.Language.CommandAst] -and
                $Node.GetCommandName() -eq 'Write-Host'
            }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "prepended"', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')

        $Diff = Show-AstDiff -Document $Overlay -EditIndex 0

        $Diff | Should -Match '\[0\] Insert greeting before Write-Host'
        $Diff | Should -Not -Match '\[1\] Replace Write-Host with Write-Output'
    }
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
