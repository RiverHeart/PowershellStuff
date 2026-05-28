using namespace System.Collections.Generic
using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'

class AstTextEdit {
    [int] $StartOffset
    [int] $EndOffset
    [string] $ReplacementText
    [string] $Reason

    AstTextEdit(
        [int] $StartOffset,
        [int] $EndOffset,
        [string] $ReplacementText,
        [string] $Reason
    ) {
        if ($StartOffset -lt 0) {
            throw 'StartOffset must be non-negative.'
        }

        if ($EndOffset -lt $StartOffset) {
            throw 'EndOffset must be greater than or equal to StartOffset.'
        }

        $this.StartOffset = $StartOffset
        $this.EndOffset = $EndOffset
        $this.ReplacementText = $ReplacementText
        $this.Reason = $Reason
    }

    [bool] Overlaps([AstTextEdit] $Other) {
        return ($this.StartOffset -lt $Other.EndOffset) -and ($Other.StartOffset -lt $this.EndOffset)
    }
}

class AstMutationPlan {
    [List[AstTextEdit]] $Edits = [List[AstTextEdit]]::new()

    [void] AddEdit([AstTextEdit] $Edit) {
        foreach ($Existing in $this.Edits) {
            if ($Existing.Overlaps($Edit)) {
                throw "Edit conflict detected between '$($Existing.Reason)' and '$($Edit.Reason)' at offsets [$($Edit.StartOffset), $($Edit.EndOffset))."
            }
        }

        $this.Edits.Add($Edit)
    }

    [AstTextEdit[]] GetSortedEdits() {
        return $this.Edits |
            Sort-Object -Property StartOffset, EndOffset
    }
}

class AstOverlay {
    [string] $Path
    [string] $OriginalText
    [Ast] $Ast
    [Token[]] $Tokens
    [ParseError[]] $ParseErrors
    [AstMutationPlan] $Plan

    AstOverlay(
        [string] $Path,
        [string] $Text,
        [Ast] $Ast,
        [Token[]] $Tokens,
        [ParseError[]] $ParseErrors
    ) {
        $this.Path = $Path
        $this.OriginalText = $Text
        $this.Ast = $Ast
        $this.Tokens = $Tokens
        $this.ParseErrors = $ParseErrors
        $this.Plan = [AstMutationPlan]::new()
    }

    [void] ReplaceNode(
        [Ast] $Node,
        [string] $NewText,
        [string] $Reason
    ) {
        $this.Plan.AddEdit([AstTextEdit]::new(
            $Node.Extent.StartOffset,
            $Node.Extent.EndOffset,
            $NewText,
            $Reason
        ))
    }

    [void] Insert(
        [int] $Offset,
        [string] $Text,
        [string] $Reason
    ) {
        $this.Plan.AddEdit([AstTextEdit]::new(
                $Offset,
                $Offset,
                $Text,
                $Reason
            ))
    }

    [void] InsertBeforeNode(
        [Ast] $Node,
        [string] $Text,
        [string] $Reason
    ) {
        $this.Insert($Node.Extent.StartOffset, $Text, $Reason)
    }

    [void] InsertAfterNode(
        [Ast] $Node,
        [string] $Text,
        [string] $Reason
    ) {
        $this.Insert($Node.Extent.EndOffset, $Text, $Reason)
    }

    [void] InsertBeforeScriptBlockClose(
        [ScriptBlockAst] $ScriptBlock,
        [string] $Text,
        [string] $Reason
    ) {
        $InsertOffset = $ScriptBlock.Extent.EndOffset - 1
        $this.Insert($InsertOffset, $Text, $Reason)
    }

    [string] Render() {
        $Edits = $this.Plan.GetSortedEdits()
        if ($Edits.Count -eq 0) {
            return $this.OriginalText
        }

        $Builder = [System.Text.StringBuilder]::new()
        $Cursor = 0

        foreach ($Edit in $Edits) {
            if ($Edit.StartOffset -lt $Cursor) {
                throw "Unexpected overlapping edit at offset $($Edit.StartOffset)."
            }

            if ($Edit.StartOffset -gt $Cursor) {
                [void] $Builder.Append($this.OriginalText.Substring($Cursor, $Edit.StartOffset - $Cursor))
            }

            [void] $Builder.Append($Edit.ReplacementText)
            $Cursor = $Edit.EndOffset
        }

        if ($Cursor -lt $this.OriginalText.Length) {
            [void] $Builder.Append($this.OriginalText.Substring($Cursor))
        }

        return $Builder.ToString()
    }
}

<#
.SYNOPSIS
    Parses script content into an immutable AST plus a mutable edit overlay plan.

.DESCRIPTION
    Creates an AstOverlay from either a file path or in-memory text.
    The returned object keeps the original source text, parse tokens, parse errors,
    and a mutation plan that can collect text edits without mutating AST nodes.
    This is the entry point for the immutable-AST + overlay workflow.

.EXAMPLE
    $doc = New-AstOverlay -Path '.\ImageViewer.DSL.ps1'

    Parses an existing script file and returns an overlay document that can receive edits.

.EXAMPLE
    $text = "Window Demo { TextBlock 'Hello' }"
    $doc = New-AstOverlay -Text $text

    Parses ad-hoc DSL text from memory for experimentation and tests.
#>
function New-AstOverlay {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([AstOverlay])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'Text')]
        [ValidateNotNullOrEmpty()]
        [string] $Text
    )

    $Tokens = $null
    $Errors = $null

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $ResolvedPath = (Resolve-Path -LiteralPath $Path).Path
        $FileText = [System.IO.File]::ReadAllText($ResolvedPath)
        $Ast = [Parser]::ParseInput($FileText, [ref] $Tokens, [ref] $Errors)

        return [AstOverlay]::new($ResolvedPath, $FileText, $Ast, $Tokens, $Errors)
    }

    $Ast = [Parser]::ParseInput($Text, [ref] $Tokens, [ref] $Errors)
    return [AstOverlay]::new('<memory>', $Text, $Ast, $Tokens, $Errors)
}

<#
.SYNOPSIS
    Validates the rendered overlay result by re-parsing it.

.DESCRIPTION
    Renders all queued edits from an AstOverlay into script text and parses
    that text again with PowerShell's parser. Returns parse diagnostics and edit counts
    so callers can gate writes or transforms on parse validity.

.EXAMPLE
    $doc = New-AstOverlay -Path '.\ImageViewer.DSL.ps1'
    Add-WpfDslLoadedHandler -Document $doc | Out-Null
    $result = Test-AstOverlay -Document $doc

    Produces parse diagnostics for the pending mutation plan.

.EXAMPLE
    $result = Test-AstOverlay -Document $doc -PassThruText
    $result.RenderedText

    Validates and also returns the fully rendered mutated script text.
#>
function Test-AstOverlay {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [AstOverlay] $Document,

        [switch] $PassThruText
    )

    $RenderedText = $Document.Render()
    $Tokens = $null
    $Errors = $null
    [void] [Parser]::ParseInput($RenderedText, [ref] $Tokens, [ref] $Errors)

    $Result = [pscustomobject] @{
        ParseErrorCount = $Errors.Count
        ParseErrors = $Errors
        EditCount = $Document.Plan.Edits.Count
        Path = $Document.Path
    }

    if ($PassThruText) {
        $Result | Add-Member -NotePropertyName RenderedText -NotePropertyValue $RenderedText
    }

    return $Result
}

<#
.SYNOPSIS
    Saves rendered overlay output to disk after parse validation succeeds.

.DESCRIPTION
    Executes the safe write flow for overlay edits. The function first renders and
    re-parses the mutated text by calling Test-AstOverlay. If parse errors are
    present, saving is blocked. If validation passes, the text is written to the target
    path and SupportsShouldProcess semantics are respected.

.EXAMPLE
    $doc = New-AstOverlay -Path '.\ImageViewer.DSL.ps1'
    Add-WpfDslLoadedHandler -Document $doc | Out-Null
    Save-AstOverlay -Document $doc -OutPath '.\ImageViewer.DSL.mutated.ps1'

    Validates then writes the mutated script to a new file.

.EXAMPLE
    Save-AstOverlay -Document $doc -WhatIf

    Shows the intended write action without changing files.
#>
function Save-AstOverlay {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [AstOverlay] $Document,

        [Parameter()]
        [string] $OutPath
    )

    $TargetPath = if ($OutPath) {
        $OutPath
    } else {
        $Document.Path
    }

    $Validation = Test-AstOverlay -Document $Document -PassThruText
    if ($Validation.ParseErrorCount -gt 0) {
        throw "Cannot save rendered output. Parse errors detected: $($Validation.ParseErrorCount)."
    }

    if ($PSCmdlet.ShouldProcess($TargetPath, 'Write rendered AST overlay output')) {
        [System.IO.File]::WriteAllText($TargetPath, $Validation.RenderedText)
    }
}

<#
.SYNOPSIS
    Inserts a missing When 'Loaded' handler into a WPF DSL Window block.

.DESCRIPTION
    Demonstrates a focused AST-driven transform for the WPF DSL. The function locates
    the first Window command with a scriptblock argument, checks whether that block
    already includes a When 'Loaded' command, then applies the configured existing-handler
    policy: skip, insert a sibling handler after the existing node, or append to the
    existing handler body. If no Loaded handler exists, a new one is inserted in the
    Window block.
    No source text is written directly; callers can validate and save through the
    overlay pipeline.

.EXAMPLE
    $doc = New-AstOverlay -Path '.\ImageViewer.DSL.ps1'
    $changed = Add-WpfDslLoadedHandler -Document $doc
    if ($changed) {
        Save-AstOverlay -Document $doc -OutPath '.\ImageViewer.DSL.mutated.ps1'
    }

    Adds a Loaded handler only when it does not already exist, then saves the result.

.EXAMPLE
    Add-WpfDslLoadedHandler -Document $doc -HandlerBody "Write-Verbose 'Window loaded'" -OnExistingHandler InsertAfterExisting

    Inserts a second Loaded handler directly beneath the existing Loaded handler.

.EXAMPLE
    Add-WpfDslLoadedHandler -Document $doc -HandlerBody "Write-Verbose 'Window loaded'" -OnExistingHandler AppendToExistingBody

    Appends new statements inside the existing Loaded handler block.
#>
function Add-WpfDslLoadedHandler {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AstOverlay] $Document,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $HandlerBody = "Write-Verbose 'Loaded handler inserted by AST overlay prototype.'",

        [Parameter()]
        [ValidateSet('Skip', 'InsertAfterExisting', 'AppendToExistingBody')]
        [string] $OnExistingHandler = 'Skip',

        [switch] $Force
    )

    $WindowCommand = $Document.Ast.Find({
            param($Node)

            $IsCommandNode = $Node -is [CommandAst]
            if (-not $IsCommandNode) {
                return $false
            }

            $Name = $Node.GetCommandName()
            $IsWindowCommand = $Name -eq 'Window'
            if (-not $IsWindowCommand) {
                return $false
            }

            $ScriptBlockArguments = $Node.CommandElements | Where-Object {
                $_ -is [ScriptBlockExpressionAst]
            }
            $HasScriptBlockArgument = $null -ne $ScriptBlockArguments

            return $HasScriptBlockArgument
        }, $true)

    if (-not $WindowCommand) {
        throw 'No WPF DSL Window command was found.'
    }

    $WindowScriptBlockExpression = $WindowCommand.CommandElements | Where-Object {
        $_ -is [ScriptBlockExpressionAst]
    } | Select-Object -First 1

    if (-not $WindowScriptBlockExpression) {
        throw 'Window command found but no scriptblock argument was detected.'
    }

    $WindowScriptBlockAst = $WindowScriptBlockExpression.ScriptBlock
    $LoadedWhenCommands = $WindowScriptBlockAst.FindAll({
            param($Node)

            $IsCommandNode = $Node -is [CommandAst]
            if (-not $IsCommandNode) {
                return $false
            }

            $IsWhenCommand = $Node.GetCommandName() -eq 'When'
            if (-not $IsWhenCommand) {
                return $false
            }

            $TooFewArgumentsGiven = $Node.CommandElements.Count -lt 2
            if ($TooFewArgumentsGiven) {
                return $false
            }

            $Literal = $Node.CommandElements[1]

            $HasStringLiteralEventName = $Literal -is [StringConstantExpressionAst]
            if (-not $HasStringLiteralEventName) {
                return $false
            }

            $IsLoadedEvent = $Literal.Value -eq 'Loaded'
            return $IsLoadedEvent
        }, $true)

    $ContainsLoadedWhen = $LoadedWhenCommands.Count -gt 0

    if ($ContainsLoadedWhen -and $Force -and $OnExistingHandler -eq 'Skip') {
        $OnExistingHandler = 'InsertAfterExisting'
    }

    if ($ContainsLoadedWhen -and $OnExistingHandler -eq 'Skip') {
        return $false
    }

    $NewWhenText = "`r`n    When 'Loaded' {`r`n        $HandlerBody`r`n    }`r`n"

    if ($ContainsLoadedWhen -and $OnExistingHandler -eq 'InsertAfterExisting') {
        $FirstLoadedWhenCommand = $LoadedWhenCommands | Select-Object -First 1
        $Document.InsertAfterNode(
            $FirstLoadedWhenCommand,
            $NewWhenText,
            'Insert sibling When Loaded handler after existing handler'
        )

        return $true
    }

    if ($ContainsLoadedWhen -and $OnExistingHandler -eq 'AppendToExistingBody') {
        $FirstLoadedWhenCommand = $LoadedWhenCommands | Select-Object -First 1
        $ExistingHandlerScriptBlockExpression = $FirstLoadedWhenCommand.CommandElements | Where-Object {
            $_ -is [ScriptBlockExpressionAst]
        } | Select-Object -First 1

        if (-not $ExistingHandlerScriptBlockExpression) {
            throw "Loaded handler was detected but no scriptblock body was found."
        }

        $ExistingHandlerScriptBlock = $ExistingHandlerScriptBlockExpression.ScriptBlock
        $WhenIndent = ' ' * ($FirstLoadedWhenCommand.Extent.StartColumnNumber - 1)
        $BodyIndent = "$WhenIndent    "
        $AppendText = "`r`n$BodyIndent$HandlerBody`r`n$WhenIndent"

        $Document.InsertBeforeScriptBlockClose(
            $ExistingHandlerScriptBlock,
            $AppendText,
            'Append text to existing When Loaded handler body'
        )

        return $true
    }

    $Document.InsertBeforeScriptBlockClose(
        $WindowScriptBlockAst,
        $NewWhenText,
        'Add missing When Loaded handler'
    )

    return $true
}
