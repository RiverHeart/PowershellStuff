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
    [OutputType([void], [object])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [object] $InputObject
    )

    process {
        $Tokens = $null
        $Errors = $null

        if ($null -ne $InputObject -and $InputObject -is [AstDocument]) {
            return $InputObject
        }

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
            $Text = $InputObject.Ast.Extent.Text
            $Ast = [Parser]::ParseInput($Text, [ref] $Tokens, [ref] $Errors)
            $NewLineSequence = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
            $Document = [AstDocument]::new('<memory>', $Text, $Ast, $Tokens, $Errors)
            $Document.NewLineSequence = $NewLineSequence
            return $Document
        }

        if ($InputObject -is [Ast]) {
            $Text = ([Ast] $InputObject).Extent.Text
            $Ast = [Parser]::ParseInput($Text, [ref] $Tokens, [ref] $Errors)
            $NewLineSequence = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
            $Document = [AstDocument]::new('<memory>', $Text, $Ast, $Tokens, $Errors)
            $Document.NewLineSequence = $NewLineSequence
            return $Document
        }

        Write-Error "Unsupported InputObject type '$($InputObject.GetType().FullName)'. Expected String, ScriptBlock, or Ast."
        return
    }
}
