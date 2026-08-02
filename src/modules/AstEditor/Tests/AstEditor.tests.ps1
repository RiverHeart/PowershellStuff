using module ../AstEditor.psd1
using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'

Describe 'New-AstDocument' {
    It 'parses string input via InputObject' {
        $Overlay = New-AstDocument -InputObject 'Window Main { }'

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.OriginalText | Should -Be 'Window Main { }'
        $Overlay.Path | Should -Be '<memory>'
    }

    It 'wraps ScriptBlock input passed via InputObject' {
        $Overlay = New-AstDocument -InputObject {
            function Get-Greeting { 'hello' }
        }
        $Functions = @($Overlay.Ast.FindAll({
                    param($Node)
                    $Node -is [FunctionDefinitionAst]
                }, $true))

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay | Should -BeOfType ([AstDocument])
        $Overlay.Ast.Extent.StartOffset | Should -Be 0
        $Functions.Name | Should -Be 'Get-Greeting'
    }

    It 'wraps Ast input passed via InputObject' {
        $Tokens = $null
        $Errors = $null
        $Ast = [Parser]::ParseInput("Window Main { }", [ref] $Tokens, [ref] $Errors)

        $Overlay = New-AstDocument -InputObject $Ast

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.Ast | Should -Not -Be $Ast
        $Overlay.Ast.Extent.StartOffset | Should -Be 0
        $Overlay.OriginalText | Should -Be 'Window Main { }'
    }

    It 'returns an existing AstDocument without coercing or reparsing it' {
        $Original = New-AstDocument -InputObject 'function Get-Greeting { ''hello'' }'

        $Resolved = New-AstDocument -InputObject $Original

        $Resolved | Should -Be $Original
    }

    It 'accepts pipeline input via InputObject' {
        $Overlay = 'Window Main { }' | New-AstDocument

        $Overlay | Should -Not -BeNullOrEmpty
        $Overlay.OriginalText | Should -Be 'Window Main { }'
        $Overlay.Path | Should -Be '<memory>'
    }

    It 'processes every pipeline input object' {
        $Overlays = @('function Get-One {}', 'function Get-Two {}') |
            New-AstDocument

        $Overlays.Count | Should -Be 2
        $Overlays[0].OriginalText | Should -Be 'function Get-One {}'
        $Overlays[1].OriginalText | Should -Be 'function Get-Two {}'
    }
}

Describe 'AstDocument line helpers' {
    It 'rejects non-AstDocument arguments at runtime' {
        { Resolve-AstDocument -Document ([pscustomobject] @{}) } |
            Should -Throw
    }

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

Describe 'Set-AstFunction' {
    It 'replaces one top-level function and its adjacent help' {
        $Source = @'
<#
.SYNOPSIS
    Old help.
#>
function Get-Greeting {
    'old'
}

function Get-Unchanged {
    'unchanged'
}
'@
        $Replacement = @'
<#
.SYNOPSIS
    New help.
#>
function Get-Greeting {
    'new'
}
'@
        $Document = New-AstDocument -InputObject $Source

        $Plan = Set-AstFunction `
            -Document $Document `
            -Name Get-Greeting `
            -Replacement $Replacement
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.IncludedHelp | Should -BeTrue
        $Plan.Name | Should -Be 'Get-Greeting'
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 1
        $Validation.RenderedText | Should -Match 'New help\.'
        $Validation.RenderedText | Should -Not -Match 'Old help\.'
        $Validation.RenderedText | Should -Match 'Get-Unchanged'
    }

    It 'preserves adjacent help when ExcludeHelp is specified' {
        $Source = @'
<#
.SYNOPSIS
    Preserved help.
#>
function Get-Greeting {
    'old'
}
'@
        $Document = New-AstDocument -InputObject $Source

        $Plan = Set-AstFunction `
            -Document $Document `
            -Name Get-Greeting `
            -Replacement "function Get-Greeting { 'new' }" `
            -ExcludeHelp
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.IncludedHelp | Should -BeFalse
        $Validation.RenderedText | Should -Match 'Preserved help\.'
        $Validation.RenderedText | Should -Match "'new'"
    }

    It 'selects a top-level function without matching a nested function of the same name' {
        $Source = @'
function Invoke-Outer {
    function Invoke-Target { 'nested' }
    Invoke-Target
}

function Invoke-Target { 'top-level' }
'@
        $Document = New-AstDocument -InputObject $Source

        $Plan = Set-AstFunction `
            -Document $Document `
            -Name Invoke-Target `
            -Replacement "function Invoke-Target { 'replaced' }"
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.TargetAst.Extent.StartLineNumber | Should -Be 6
        $Validation.RenderedText | Should -Match "Invoke-Target \{ 'nested' \}"
        $Validation.RenderedText | Should -Match "Invoke-Target \{ 'replaced' \}"
    }

    It 'requires Recurse to select a nested function' {
        $Source = @'
function Invoke-Outer {
    function Invoke-Target { 'nested' }
}
'@
        $Document = New-AstDocument -InputObject $Source

        {
            Set-AstFunction `
                -Document $Document `
                -Name Invoke-Target `
                -Replacement "function Invoke-Target { 'new' }"
        } | Should -Throw "Function 'Invoke-Target' was not found in the top level of the document."

        $Plan = Set-AstFunction `
            -Document $Document `
            -Name Invoke-Target `
            -Replacement "function Invoke-Target { 'new' }" `
            -Recurse

        $Plan.TargetAst.Extent.StartLineNumber | Should -Be 2
    }

    It 'rejects ambiguous recursive matches with source locations' {
        $Source = @'
function Invoke-First {
    function Invoke-Target { 'first' }
}
function Invoke-Second {
    function Invoke-Target { 'second' }
}
'@
        $Document = New-AstDocument -InputObject $Source

        {
            Set-AstFunction `
                -Document $Document `
                -Name Invoke-Target `
                -Replacement "function Invoke-Target { 'new' }" `
                -Recurse
        } | Should -Throw "Function 'Invoke-Target' is ambiguous. Matches were found at 2:5, 5:5."
    }

    It 'rejects replacement text that is not exactly one function definition' {
        $Document = New-AstDocument -InputObject "function Get-Greeting { 'old' }"

        {
            Set-AstFunction `
                -Document $Document `
                -Name Get-Greeting `
                -Replacement "function Get-One {}; function Get-Two {}"
        } | Should -Throw 'Replacement must contain exactly one complete function definition.'

        $Document.Edits.Count | Should -Be 0
    }

    It 'rejects malformed replacement text before queuing an edit' {
        $Document = New-AstDocument -InputObject "function Get-Greeting { 'old' }"

        {
            Set-AstFunction `
                -Document $Document `
                -Name Get-Greeting `
                -Replacement 'function Get-Greeting {'
        } | Should -Throw 'Replacement text contains * parse error(s): *'

        $Document.Edits.Count | Should -Be 0
    }
}

Describe 'Edit-PSFunction' {
    It 'accepts an existing AstDocument without coercing it to a string' {
        $Document = New-AstDocument -InputObject 'function foo { Write-Host foo }'

        $Result = Edit-PSFunction `
            -InputObject $Document `
            -Name foo `
            -Replacement 'function foo { Write-Host fubar }'

        $Result.Document | Should -Be $Document
        $Result.RenderedText | Should -Be 'function foo { Write-Host fubar }'
    }

    It 'accepts a ScriptBlock and finds functions within its normalized AST' {
        $Result = Edit-PSFunction `
            -InputObject { function foo { Write-Host foo } } `
            -Name foo `
            -Replacement 'function foo { Write-Host fubar }'

        $Result.ParseErrorCount | Should -Be 0
        $Result.RenderedText | Should -Match 'function foo \{ Write-Host fubar \}'
    }

    It 'returns a preview without changing the file by default' {
        $Path = Join-Path $TestDrive 'Preview.ps1'
        "function Get-Greeting { 'old' }" | Set-Content -LiteralPath $Path -NoNewline

        $Result = Edit-PSFunction `
            -Path $Path `
            -Name Get-Greeting `
            -Replacement "function Get-Greeting { 'new' }"

        $Result.Applied | Should -BeFalse
        $Result.ParseErrorCount | Should -Be 0
        $Result.EditCount | Should -Be 1
        $Result.Diff | Should -Match "function Get-Greeting \{ 'new' \}"
        [System.IO.File]::ReadAllText($Path) | Should -Be "function Get-Greeting { 'old' }"
    }

    It 'writes the validated replacement only when Apply is specified' {
        $Path = Join-Path $TestDrive 'Apply.ps1'
        "function Get-Greeting { 'old' }" | Set-Content -LiteralPath $Path -NoNewline

        $Result = Edit-PSFunction `
            -Path $Path `
            -Name Get-Greeting `
            -Replacement "function Get-Greeting { 'new' }" `
            -Apply `
            -Confirm:$false

        $Result.Applied | Should -BeTrue
        [System.IO.File]::ReadAllText($Path) | Should -Be "function Get-Greeting { 'new' }"
    }

    It 'does not write when Apply and WhatIf are used together' {
        $Path = Join-Path $TestDrive 'WhatIf.ps1'
        "function Get-Greeting { 'old' }" | Set-Content -LiteralPath $Path -NoNewline

        $Result = Edit-PSFunction `
            -Path $Path `
            -Name Get-Greeting `
            -Replacement "function Get-Greeting { 'new' }" `
            -Apply `
            -WhatIf

        $Result.Applied | Should -BeFalse
        $Result.Diff | Should -Match "function Get-Greeting \{ 'new' \}"
        [System.IO.File]::ReadAllText($Path) | Should -Be "function Get-Greeting { 'old' }"
    }
}

Describe 'Extract-AstFunction' {
    It 'extracts a top-level function with its adjacent help' {
        $Source = @'
<#
.SYNOPSIS
    Extracted help.
#>
function Get-Extracted {
    'extracted'
}

function Get-Remaining {
    'remaining'
}
'@
        $Document = New-AstDocument -InputObject $Source

        $Plan = Extract-AstFunction -Document $Document -Name Get-Extracted
        $Validation = Resolve-AstDocument -Document $Document -PassThruText

        $Plan.IncludedHelp | Should -BeTrue
        $Plan.Text | Should -Match 'Extracted help\.'
        $Plan.Text | Should -Match 'function Get-Extracted'
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.RenderedText | Should -Not -Match 'Get-Extracted'
        $Validation.RenderedText | Should -Match 'Get-Remaining'
    }

    It 'does not treat class constructors or methods as top-level functions' {
        $Source = @'
class Example {
    Example() {}
    [void] Invoke() {}
}

function Get-Remaining { 'remaining' }
'@
        $Document = New-AstDocument -InputObject $Source

        {
            Extract-AstFunction -Document $Document -Name Example
        } | Should -Throw "Function 'Example' was not found in the top level of the document."

        $Document.Edits.Count | Should -Be 0
    }
}

Describe 'Split-PSFunction' {
    It 'previews splitting all top-level functions without writing files' {
        $Path = Join-Path $TestDrive 'Module.psm1'
        $OutputDirectory = Join-Path $TestDrive 'Private'
        @'
function Get-One { 'one' }
function Get-Two { 'two' }
'@ | Set-Content -LiteralPath $Path -NoNewline

        $Result = Split-PSFunction -Path $Path -OutputDirectory $OutputDirectory

        $Result.Applied | Should -BeFalse
        $Result.Files.Name | Should -Be @('Get-One', 'Get-Two')
        $Result.EditCount | Should -Be 2
        $Result.ParseErrorCount | Should -Be 0
        Test-Path -LiteralPath $OutputDirectory | Should -BeFalse
        [System.IO.File]::ReadAllText($Path) | Should -Match 'Get-One'
    }

    It 'writes extracted files and removes functions from the source with Apply' {
        $Path = Join-Path $TestDrive 'Module.psm1'
        $OutputDirectory = Join-Path $TestDrive 'Private'
        @'
$ModuleName = 'Example'

function Get-One { 'one' }
function Get-Two { 'two' }
'@ | Set-Content -LiteralPath $Path -NoNewline

        $Result = Split-PSFunction `
            -Path $Path `
            -OutputDirectory $OutputDirectory `
            -Apply `
            -Confirm:$false

        $Result.Applied | Should -BeTrue
        [System.IO.File]::ReadAllText((Join-Path $OutputDirectory 'Get-One.ps1')) |
            Should -Be "function Get-One { 'one' }"
        [System.IO.File]::ReadAllText((Join-Path $OutputDirectory 'Get-Two.ps1')) |
            Should -Be "function Get-Two { 'two' }"
        [System.IO.File]::ReadAllText($Path) | Should -Match '\$ModuleName'
        [System.IO.File]::ReadAllText($Path) | Should -Not -Match 'function Get-'
    }

    It 'does not overwrite an existing function file without Force' {
        $Path = Join-Path $TestDrive 'Module.psm1'
        $OutputDirectory = Join-Path $TestDrive 'Private'
        $DestinationPath = Join-Path $OutputDirectory 'Get-One.ps1'
        $null = New-Item -ItemType Directory -Path $OutputDirectory -Force
        "function Get-One { 'original' }" | Set-Content -LiteralPath $Path -NoNewline
        'existing content' | Set-Content -LiteralPath $DestinationPath -NoNewline

        {
            Split-PSFunction `
                -Path $Path `
                -OutputDirectory $OutputDirectory `
                -Apply `
                -Confirm:$false
        } | Should -Throw "Destination file '$DestinationPath' already exists. Use Force to overwrite it."

        [System.IO.File]::ReadAllText($Path) | Should -Match 'function Get-One'
        [System.IO.File]::ReadAllText($DestinationPath) | Should -Be 'existing content'
    }

    It 'does not write the source or extracted files under WhatIf' {
        $Path = Join-Path $TestDrive 'WhatIfModule.psm1'
        $OutputDirectory = Join-Path $TestDrive 'WhatIfPrivate'
        "function Get-One { 'one' }" | Set-Content -LiteralPath $Path -NoNewline

        $Result = Split-PSFunction `
            -Path $Path `
            -OutputDirectory $OutputDirectory `
            -Apply `
            -WhatIf

        $Result.Applied | Should -BeFalse
        Test-Path -LiteralPath $OutputDirectory | Should -BeFalse
        [System.IO.File]::ReadAllText($Path) | Should -Match 'function Get-One'
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

InModuleScope AstEditor {
    Describe 'WPF Loaded-handler rewrite plan MVP' {
        It 'builds an InsertMissingHandler plan and emits one edit' {
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

        It 'builds a None plan when identical Loaded body already exists' {
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
