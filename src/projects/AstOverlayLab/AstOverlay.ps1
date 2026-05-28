using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Represents a single text edit operation with start and end offsets,
    replacement text, and a reason for the edit.
#>
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

<#
.SYNOPSIS
    Holds parsed script data, a pending list of text edits, and helper methods for queuing them.

.DESCRIPTION
    AstDocument is a lightweight document object for already-parsed script content.
    It does not parse files itself. Use New-AstDocument when you want to load a file
    path or raw text and get back a ready-to-edit document instance. The constructor
    simply stores the parsed inputs and initializes the edit list.

    The edits collected in an AstDocument are not applied to the underlying AST nodes.
    Instead, they are stored as text edits with source offsets. This allows the AST
    to remain immutable and reusable for multiple edit passes, while the document tracks
    the cumulative effect of all edits for rendering and validation.

.NOTES
    `Render()` walks the edits in `StartOffset` order, appends the untouched original text
    from the current cursor up to each edit’s original `StartOffset`, then appends the
    replacement text and advances the cursor to that edit’s original `EndOffset`.
    So earlier edits do not shift later offsets because nothing is being mutated in
    place while the loop runs.

    The one thing that is required is non-overlap. If two edits target overlapping
    original spans, `AddEdit()` or the render loop will reject them rather than
    trying to reconcile shifted positions.

.EXAMPLE
    $doc = New-AstDocument -Path '.\ImageViewer.DSL.ps1'

    Loads and parses a file, then returns an AstDocument instance you can edit.

.EXAMPLE
    $doc = New-AstDocument -InputObject "Window Demo { TextBlock 'Hello' }"
    Add-WpfDslLoadedHandler -Document $doc | Out-Null

    Parses in-memory text and applies a transform to the resulting document.
#>
class AstDocument {
    # Preserves source provenance and gives Save-AstDocument a default target path.
    [string] $Path
    [string] $OriginalText
    [string] $NewLineSequence = "`n"
    [Ast] $Ast
    [Token[]] $Tokens
    [ParseError[]] $ParseErrors
    [List[AstTextEdit]] $Edits = [List[AstTextEdit]]::new()

    AstDocument(
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
    }

    hidden [void] AddEdit([AstTextEdit] $Edit) {
        foreach ($Existing in $this.Edits) {
            if ($Existing.Overlaps($Edit)) {
                throw "Edit conflict detected between '$($Existing.Reason)' and '$($Edit.Reason)' at offsets [$($Edit.StartOffset), $($Edit.EndOffset))."
            }
        }

        $this.Edits.Add($Edit)
    }

    hidden [AstTextEdit[]] GetSortedEdits() {
        return $this.Edits | Sort-Object -Property StartOffset, EndOffset
    }

    [void] ClearEdits() {
        $this.Edits.Clear()
    }

    [void] Replace(
        [Ast] $Node,
        [string] $NewText,
        [string] $Reason
    ) {
        $this.AddEdit([AstTextEdit]::new(
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
        $this.AddEdit([AstTextEdit]::new(
            $Offset,
            $Offset,
            $Text,
            $Reason
        ))
    }

    [void] Prepend(
        [Ast] $Node,
        [string] $Text,
        [string] $Reason
    ) {
        $this.Insert($Node.Extent.StartOffset, $Text, $Reason)
    }

    [void] PrependLine(
        [Ast] $Node,
        [string] $Text,
        [string] $Reason
    ) {
        $ResolvedText = "$($this.GetIndent($Node))$Text$($this.NewLineSequence)"
        $LineStartOffset = $this.GetLineStartOffset($Node)
        $this.Insert($LineStartOffset, $ResolvedText, $Reason)
    }

    [void] Append(
        [Ast] $Node,
        [string] $Text,
        [string] $Reason
    ) {
        $this.Insert($Node.Extent.EndOffset, $Text, $Reason)
    }

    [void] AppendLine(
        [Ast] $Node,
        [string] $Text,
        [string] $Reason
    ) {
        $ResolvedText = "$($this.NewLineSequence)$($this.GetIndent($Node))$Text"
        $this.Append($Node, $ResolvedText, $Reason)
    }

    [string] GetIndent([Ast] $Node) {
        $StartOffset = $Node.Extent.StartOffset
        if ($StartOffset -le 0) {
            return ''
        }

        $LineStart = $this.OriginalText.LastIndexOf("`n", [Math]::Min($StartOffset - 1, $this.OriginalText.Length - 1))
        if ($LineStart -lt 0) {
            $LineStart = -1
        }

        $IndentStart = $LineStart + 1
        $IndentLength = 0
        while (($IndentStart + $IndentLength) -lt $StartOffset) {
            $Character = $this.OriginalText[$IndentStart + $IndentLength]
            if (($Character -ne ' ') -and ($Character -ne "`t")) {
                break
            }

            $IndentLength++
        }

        return $this.OriginalText.Substring($IndentStart, $IndentLength)
    }

    hidden [int] GetLineStartOffset([Ast] $Node) {
        $StartOffset = $Node.Extent.StartOffset
        if ($StartOffset -le 0) {
            return 0
        }

        $LineBreakOffset = $this.OriginalText.LastIndexOf("`n", [Math]::Min($StartOffset - 1, $this.OriginalText.Length - 1))
        return $LineBreakOffset + 1
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
        $SortedEdits = $this.GetSortedEdits()
        if ($SortedEdits.Count -eq 0) {
            return $this.OriginalText
        }

        $Builder = [System.Text.StringBuilder]::new()
        $Cursor = 0

        foreach ($Edit in $SortedEdits) {
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
    Parses script content into an AstDocument ready to receive edits.

.DESCRIPTION
    Creates an AstDocument from a file path, string text, ScriptBlock, or already
    parsed Ast via the InputObject parameter. The returned object keeps the original
    source text, parse tokens, parse errors, and an edit list that can collect
    text edits without mutating AST nodes. This is the entry point for the
    immutable-AST + overlay workflow.

.EXAMPLE
    $doc = New-AstDocument -Path '.\ImageViewer.DSL.ps1'

    Parses an existing script file and returns a document that can receive edits.

.EXAMPLE
    $doc = New-AstDocument -InputObject 'Window Demo { }'

    Parses ad-hoc DSL text from memory for experimentation and tests.

.EXAMPLE
    $doc = New-AstDocument -InputObject { Window Demo { } }

    Uses a ScriptBlock input directly without an explicit parse step.

.EXAMPLE
    $tokens = $null
    $errors = $null
    $ast = [Parser]::ParseInput("Window Demo { }", [ref] $tokens, [ref] $errors)
    $doc = New-AstDocument -InputObject $ast

    Wraps an already parsed AST in a document.
#>
function New-AstDocument {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([void], [AstDocument])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [object] $InputObject
    )

    $Tokens = $null
    $Errors = $null

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $ResolvedPath = (Resolve-Path -LiteralPath $Path).Path
        $FileText = [File]::ReadAllText($ResolvedPath)
        $Ast = [Parser]::ParseInput($FileText, [ref] $Tokens, [ref] $Errors)
        $NewLineSequence = if ($FileText.Contains("`r`n")) { "`r`n" } else { "`n" }
        $Document = [AstDocument]::new($ResolvedPath, $FileText, $Ast, $Tokens, $Errors)
        $Document.NewLineSequence = $NewLineSequence
        return $Document
    }

    if ($InputObject -is [string]) {
        $Text = [string] $InputObject
        $Ast = [Parser]::ParseInput($Text, [ref] $Tokens, [ref] $Errors)
        $NewLineSequence = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
        $Document = [AstDocument]::new('<memory>', $Text, $Ast, $Tokens, $Errors)
        $Document.NewLineSequence = $NewLineSequence
        return $Document
    }

    if ($InputObject -is [ScriptBlock]) {
        $Ast = $InputObject.Ast
        $Text = $Ast.Extent.Text
        $NewLineSequence = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
        $Document = [AstDocument]::new('<memory>', $Text, $Ast, $Tokens, $Errors)
        $Document.NewLineSequence = $NewLineSequence
        return $Document
    }

    if ($InputObject -is [Ast]) {
        $Ast = [Ast] $InputObject
        $Text = $Ast.Extent.Text
        $NewLineSequence = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
        $Document = [AstDocument]::new('<memory>', $Text, $Ast, $Tokens, $Errors)
        $Document.NewLineSequence = $NewLineSequence
        return $Document
    }

    Write-Error "Unsupported InputObject type '$($InputObject.GetType().FullName)'. Expected String, ScriptBlock, or Ast."
    return
}

<#
.SYNOPSIS
    Renders queued edits and re-parses the result, returning diagnostics.

.DESCRIPTION
    Renders all queued edits from an AstDocument into script text and parses
    that text again with PowerShell's parser. Returns parse diagnostics and edit counts
    so callers can gate writes or transforms on parse validity.

.EXAMPLE
    $doc = New-AstDocument -Path '.\ImageViewer.DSL.ps1'
    Add-WpfDslLoadedHandler -Document $doc | Out-Null
    $result = Resolve-AstDocument -Document $doc

    Produces parse diagnostics for the pending edits.

.EXAMPLE
    $result = Resolve-AstDocument -Document $doc -PassThruText
    $result.RenderedText

    Validates and also returns the fully rendered mutated script text.
#>
function Resolve-AstDocument {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [switch] $PassThruText
    )

    $RenderedText = $Document.Render()
    $Tokens = $null
    $Errors = $null
    [void] [Parser]::ParseInput($RenderedText, [ref] $Tokens, [ref] $Errors)

    $Result = [pscustomobject] @{
        ParseErrorCount = $Errors.Count
        ParseErrors = $Errors
        EditCount = $Document.Edits.Count
        Path = $Document.Path
    }

    if ($PassThruText) {
        $Result | Add-Member -NotePropertyName RenderedText -NotePropertyValue $RenderedText
    }

    return $Result
}

<#
.SYNOPSIS
    Shows a text diff for all or selected queued edits in an AstDocument.

.DESCRIPTION
    Formats the queued edits as numbered diff blocks based on the document's
    sorted edit list. When EditIndex is provided, only those zero-based edit
    positions are shown. The output is intended for quick inspection rather than
    patch application.

.EXAMPLE
    Show-AstDiff -Document $doc

    Displays every queued edit in sorted order.

.EXAMPLE
    Show-AstDiff -Document $doc -EditIndex 0,2

    Displays only the first and third queued edits.
#>
function Show-AstDiff {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter()]
        [int[]] $EditIndex
    )

    $SortedEdits = $Document.Edits | Sort-Object -Property StartOffset, EndOffset
    if ($SortedEdits.Count -eq 0) {
        return 'No queued edits.'
    }

    if ($PSBoundParameters.ContainsKey('EditIndex')) {
        $SelectedIndexes = $EditIndex | Sort-Object -Unique
    } else {
        $SelectedIndexes = 0..($SortedEdits.Count - 1)
    }

    $Builder = [System.Text.StringBuilder]::new()
    foreach ($Index in $SelectedIndexes) {
        if (($Index -lt 0) -or ($Index -ge $SortedEdits.Count)) {
            throw "Edit index $Index is out of range. Valid range is 0..$($SortedEdits.Count - 1)."
        }

        $Edit = $SortedEdits[$Index]
        $OriginalText = if ($Edit.EndOffset -gt $Edit.StartOffset) {
            $Document.OriginalText.Substring($Edit.StartOffset, $Edit.EndOffset - $Edit.StartOffset)
        } else {
            '<insert>'
        }

        if ($Builder.Length -gt 0) {
            [void] $Builder.AppendLine('')
        }

        [void] $Builder.AppendLine("[$Index] $($Edit.Reason)")
        [void] $Builder.AppendLine("  Offsets: $($Edit.StartOffset)..$($Edit.EndOffset)")
        [void] $Builder.AppendLine('  --- original ---')
        [void] $Builder.AppendLine($OriginalText)
        [void] $Builder.AppendLine('  +++ replacement +++')
        [void] $Builder.AppendLine($Edit.ReplacementText)
    }

    return $Builder.ToString().TrimEnd()
}

<#
.SYNOPSIS
    Saves rendered document output to disk after parse validation succeeds.

.DESCRIPTION
    Executes the safe write flow for document edits. The function first renders and
    re-parses the mutated text by calling Resolve-AstDocument. If parse errors are
    present, saving is blocked. If validation passes, the text is written to the target
    path and SupportsShouldProcess semantics are respected.

.EXAMPLE
    $doc = New-AstDocument -Path '.\ImageViewer.DSL.ps1'
    Add-WpfDslLoadedHandler -Document $doc | Out-Null
    Save-AstDocument -Document $doc -OutPath '.\ImageViewer.DSL.mutated.ps1'

    Validates then writes the mutated script to a new file.

.EXAMPLE
    Save-AstDocument -Document $doc -WhatIf

    Shows the intended write action without changing files.
#>
function Save-AstDocument {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter()]
        [string] $OutPath
    )

    $TargetPath = if ($OutPath) {
        $OutPath
    } else {
        $Document.Path
    }

    $Validation = Resolve-AstDocument -Document $Document -PassThruText
    if ($Validation.ParseErrorCount -gt 0) {
        throw "Cannot save rendered output. Parse errors detected: $($Validation.ParseErrorCount)."
    }

    if ($PSCmdlet.ShouldProcess($TargetPath, 'Write rendered AST overlay output')) {
        [File]::WriteAllText($TargetPath, $Validation.RenderedText)
    }
}

<#
.SYNOPSIS
    Inserts a missing When 'Loaded' handler into a WPF DSL Window block.

.DESCRIPTION
    A focused AST-driven transform for the WPF DSL. The function locates
    the first Window command with a scriptblock argument, checks whether that block
    already includes a When 'Loaded' command, then applies the configured existing-handler
    policy: skip, insert a sibling handler after the existing node, or append to the
    existing handler body. If no Loaded handler exists, a new one is inserted in the
    Window block. By default, identical handler bodies are treated as already present
    and are not reinserted or re-appended.
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
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $HandlerBody = "Write-Verbose 'Loaded handler inserted by AST overlay prototype.'",

        [Parameter()]
        [ValidateSet('Skip', 'InsertAfterExisting', 'AppendToExistingBody')]
        [string] $OnExistingHandler = 'Skip',

        [switch] $AllowDuplicateHandlerBody,

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

    $HandlerBodyAlreadyPresent = $false
    foreach ($LoadedWhenCommand in $LoadedWhenCommands) {
        $LoadedHandlerScriptBlockExpression = $LoadedWhenCommand.CommandElements | Where-Object {
            $_ -is [ScriptBlockExpressionAst]
        } | Select-Object -First 1

        if (-not $LoadedHandlerScriptBlockExpression) {
            continue
        }

        $LoadedHandlerScriptBlockText = $LoadedHandlerScriptBlockExpression.ScriptBlock.Extent.Text
        $LoadedHandlerContainsBody = $LoadedHandlerScriptBlockText.Contains($HandlerBody)
        if ($LoadedHandlerContainsBody) {
            $HandlerBodyAlreadyPresent = $true
            break
        }
    }

    if ($ContainsLoadedWhen -and $Force -and $OnExistingHandler -eq 'Skip') {
        $OnExistingHandler = 'InsertAfterExisting'
    }

    if ($ContainsLoadedWhen -and -not $AllowDuplicateHandlerBody -and $HandlerBodyAlreadyPresent) {
        return $false
    }

    if ($ContainsLoadedWhen -and $OnExistingHandler -eq 'Skip') {
        return $false
    }

    $NewWhenText = "`r`n    When 'Loaded' {`r`n        $HandlerBody`r`n    }`r`n"

    if ($ContainsLoadedWhen -and $OnExistingHandler -eq 'InsertAfterExisting') {
        $FirstLoadedWhenCommand = $LoadedWhenCommands | Select-Object -First 1
        $Document.Append(
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
