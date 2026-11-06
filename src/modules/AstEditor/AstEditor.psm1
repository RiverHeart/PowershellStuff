using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation.Language
using namespace System.Text

class AstScriptPosition : IScriptPosition {
    hidden [string] $SourceFile
    hidden [string] $SourceText
    hidden [string] $LineText
    hidden [int] $SourceOffset
    hidden [int] $SourceLine
    hidden [int] $SourceColumn

    AstScriptPosition(
        [string] $File,
        [string] $Text,
        [int] $Offset,
        [int] $LineNumber,
        [int] $ColumnNumber,
        [string] $Line
    ) {
        $this.SourceFile = $File
        $this.SourceText = $Text
        $this.SourceOffset = $Offset
        $this.SourceLine = $LineNumber
        $this.SourceColumn = $ColumnNumber
        $this.LineText = $Line
    }

    [string] get_File() { return $this.SourceFile }
    [int] get_LineNumber() { return $this.SourceLine }
    [int] get_ColumnNumber() { return $this.SourceColumn }
    [int] get_Offset() { return $this.SourceOffset }
    [string] get_Line() { return $this.LineText }
    [string] GetFullScript() { return $this.SourceText }
}

class AstScriptExtent : IScriptExtent {
    hidden [IScriptPosition] $StartPosition
    hidden [IScriptPosition] $EndPosition

    AstScriptExtent([IScriptPosition] $Start, [IScriptPosition] $End) {
        $this.StartPosition = $Start
        $this.EndPosition = $End
    }

    [string] get_File() { return $this.StartPosition.File }
    [IScriptPosition] get_StartScriptPosition() { return $this.StartPosition }
    [IScriptPosition] get_EndScriptPosition() { return $this.EndPosition }
    [int] get_StartLineNumber() { return $this.StartPosition.LineNumber }
    [int] get_StartColumnNumber() { return $this.StartPosition.ColumnNumber }
    [int] get_EndLineNumber() { return $this.EndPosition.LineNumber }
    [int] get_EndColumnNumber() { return $this.EndPosition.ColumnNumber }
    [int] get_StartOffset() { return $this.StartPosition.Offset }
    [int] get_EndOffset() { return $this.EndPosition.Offset }
    [string] get_Text() {
        return $this.StartPosition.GetFullScript().Substring(
            $this.StartPosition.Offset,
            $this.EndPosition.Offset - $this.StartPosition.Offset
        )
    }
}

<#
.SYNOPSIS
    Represents a detached text edit with source coordinates, expected text,
    replacement text, and a reason.
#>
class AstTextEdit {
    [int] $StartLineNumber
    [int] $EndLineNumber
    [int] $StartColumnNumber
    [int] $EndColumnNumber
    [int] $StartOffset
    [int] $EndOffset
    [string] $ExpectedText
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

    AstTextEdit([hashtable] $Properties) {
        $this.StartLineNumber = $Properties.StartLineNumber
        $this.EndLineNumber = $Properties.EndLineNumber
        $this.StartColumnNumber = $Properties.StartColumnNumber
        $this.EndColumnNumber = $Properties.EndColumnNumber
        $this.StartOffset = $Properties.StartOffset
        $this.EndOffset = $Properties.EndOffset
        $this.ExpectedText = $Properties.ExpectedText
        $this.ReplacementText = $Properties.ReplacementText
        $this.Reason = $Properties.Reason

        if ($this.StartOffset -lt 0) {
            throw 'StartOffset must be non-negative.'
        }
        if ($this.EndOffset -lt $this.StartOffset) {
            throw 'EndOffset must be greater than or equal to StartOffset.'
        }
        if ($null -ne $this.ExpectedText -and $this.ExpectedText.Length -ne ($this.EndOffset - $this.StartOffset)) {
            throw 'ExpectedText length must match the offset range.'
        }
    }

    [bool] Overlaps([AstTextEdit] $Other) {
        return ($this.StartOffset -lt $Other.EndOffset) -and ($Other.StartOffset -lt $this.EndOffset)
    }
}

class AstTextEditResult {
    [string] $Status
    [string] $Path
    [AstTextEdit] $TextEdit
    [int] $StartOffset
    [int] $EndOffset
    [string] $ReplacementText
    [string] $Reason
    [string] $ExpectedText

    AstTextEditResult(
        [string] $Path,
        [AstTextEdit] $TextEdit
    ) {
        $this.Status = 'Queued'
        $this.Path = $Path
        $this.TextEdit = $TextEdit
        $this.StartOffset = $TextEdit.StartOffset
        $this.EndOffset = $TextEdit.EndOffset
        $this.ReplacementText = $TextEdit.ReplacementText
        $this.Reason = $TextEdit.Reason
        $this.ExpectedText = $TextEdit.ExpectedText
    }
}

class AstParseData {
    [Ast] $Ast
    [Token[]] $Tokens
    [ParseError[]] $ParseErrors
}

class AstDocument {
    # A default save target, distinct from the parser's informational source file.
    [string] $Path
    [string] $OriginalText
    [string] $OriginalFingerprint
    [bool] $IsFileBacked
    [Encoding] $SourceEncoding = [UTF8Encoding]::new($false, $true)
    [string] $NewLineSequence = "`n"
    [Ast] $Ast
    [AstParseData] $Root = [AstParseData]::new()
    [bool] $IsFragment
    [Token[]] $Tokens
    [ParseError[]] $ParseErrors
    [List[AstTextEdit]] $Edits = [List[AstTextEdit]]::new()

    AstDocument(
        [ScriptBlock] $ScriptBlock
    ) {
        $this.InitFromAst($ScriptBlock.Ast)
    }

    AstDocument(
        [Ast] $Ast
    ) {
        $this.InitFromAst($Ast)
    }

    AstDocument(
        [string] $Text
    ) {
        $this.Init('<memory>', $Text, $null)
    }

    AstDocument(
        [string] $Path,
        [string] $Text
    ) {
        $this.Init($Path, $Text, $Path)
    }

    hidden [void] InitFromAst([Ast] $InputAst) {
        $Extent = $InputAst.Extent
        $Snapshot = $Extent.StartScriptPosition.GetFullScript()
        if ($null -eq $Snapshot) {
            $this.Init('<memory>', $Extent.Text, $Extent.File)
        } else {
            if ($Extent.StartOffset -lt 0 -or
                $Extent.EndOffset -lt $Extent.StartOffset -or
                $Extent.EndOffset -gt $Snapshot.Length -or
                $Snapshot.Substring($Extent.StartOffset, $Extent.EndOffset - $Extent.StartOffset) -cne $Extent.Text
            ) {
                throw [ArgumentException]::new('The supplied AST extent does not match its source snapshot.')
            }

            $this.Init('<memory>', $Snapshot, $Extent.File)
            $this.Ast = $this.FindFragment($this.Root.Ast, $InputAst, $Extent.EndOffset)
            $this.IsFragment = -not [object]::ReferenceEquals($this.Ast, $this.Root.Ast)
            if ($this.IsFragment) {
                $this.Tokens = $this.GetFragmentTokens($this.Root.Tokens)
                $this.ParseErrors = @($this.Root.ParseErrors | Where-Object {
                    $_.Extent.StartOffset -ge $this.Ast.Extent.StartOffset
                })
            }
        }
    }

    hidden [Token[]] GetFragmentTokens([Token[]] $SourceTokens) {
        $SelectedTokens = [List[Token]]::new()
        foreach ($Token in $SourceTokens) {
            if ($Token.Extent.StartOffset -ge $this.Ast.Extent.StartOffset -and
                $Token.Extent.EndOffset -le $this.Ast.Extent.EndOffset
            ) {
                $SelectedTokens.Add($Token)
            } elseif ($Token -is [StringExpandableToken]) {
                # The parser nests tokens for $() inside expandable strings.
                foreach ($NestedToken in $this.GetFragmentTokens($Token.NestedTokens)) {
                    $SelectedTokens.Add($NestedToken)
                }
            }
        }
        return $SelectedTokens.ToArray()
    }

    hidden [Ast] FindFragment([Ast] $Root, [Ast] $Fragment, [int] $EndOffset) {
        $Depth = 0
        $Ancestor = $Fragment
        while ($null -ne $Ancestor.Parent) {
            $Depth++
            $Ancestor = $Ancestor.Parent
        }

        $Candidates = @($Root.FindAll({
            param($Node)

            if ($Node.GetType() -ne $Fragment.GetType() -or
                $Node.Extent.StartOffset -ne $Fragment.Extent.StartOffset -or
                $Node.Extent.EndOffset -ne $EndOffset
            ) {
                return $false
            }

            $NodeDepth = 0
            $Parent = $Node
            while ($null -ne $Parent.Parent) {
                $NodeDepth++
                $Parent = $Parent.Parent
            }
            return $NodeDepth -eq $Depth
        }, $true))

        if ($Candidates.Count -ne 1) {
            throw [InvalidOperationException]::new(
                "Could not uniquely locate the submitted fragment ($($Fragment.GetType().Name), depth $Depth) at offsets [$($Fragment.Extent.StartOffset), $EndOffset) in the source snapshot; found $($Candidates.Count) matches."
            )
        }
        return $Candidates[0]
    }

    hidden [int] GetRenderedFragmentEndOffset() {
        $EndOffset = $this.Ast.Extent.EndOffset
        foreach ($Edit in $this.Edits) {
            $EndOffset += $Edit.ReplacementText.Length - ($Edit.EndOffset - $Edit.StartOffset)
        }
        return $EndOffset
    }

    hidden [void] Init([string] $Path, [string] $Text, [string] $SourcePath) {
        $this.Path = $Path
        $this.OriginalText = $Text
        $this.OriginalFingerprint = Get-AstSourceFingerprint -Bytes (
            $this.SourceEncoding.GetBytes($this.OriginalText)
        )
        $ParsedTokens = $null
        $Errors = $null
        $this.Root.Ast = [Parser]::ParseInput(
            $this.OriginalText, $SourcePath, [ref] $ParsedTokens, [ref] $Errors
        )
        $this.Ast = $this.Root.Ast
        $this.Root.Tokens = $ParsedTokens
        $this.Tokens = $this.Root.Tokens
        $this.Root.ParseErrors = $Errors
        $this.ParseErrors = $this.Root.ParseErrors
        $this.NewLineSequence = if ($this.OriginalText.Contains("`r`n")) { "`r`n" } else { "`n" }
    }

    hidden [void] ValidateEditTarget([AstTextEdit] $Edit) {
        if ($this.IsFragment -and
            ($Edit.StartOffset -lt $this.Ast.Extent.StartOffset -or
            $Edit.EndOffset -gt $this.Ast.Extent.EndOffset)
        ) {
            $Exception = [InvalidOperationException]::new(
                "Edit '$($Edit.Reason)' at offsets [$($Edit.StartOffset), $($Edit.EndOffset)) falls outside the submitted fragment [$($this.Ast.Extent.StartOffset), $($this.Ast.Extent.EndOffset))."
            )
            $Exception.Data['FailureKind'] = 'OutsideTarget'
            $Exception.Data['IncomingEdit'] = @{
                StartOffset = $Edit.StartOffset
                EndOffset = $Edit.EndOffset
                ReplacementText = $Edit.ReplacementText
                ExpectedText = $Edit.ExpectedText
                Reason = $Edit.Reason
            }
            throw $Exception
        }
    }

    hidden [void] AddEdit([AstTextEdit] $Edit) {
        $this.ValidateEditTarget($Edit)
        foreach ($Existing in $this.Edits) {
            $HasSharedInsertionOffset =
                $Existing.StartOffset -eq $Existing.EndOffset -and
                $Edit.StartOffset -eq $Edit.EndOffset -and
                $Existing.StartOffset -eq $Edit.StartOffset

            if ($Existing.Overlaps($Edit) -or $HasSharedInsertionOffset) {
                $Message = "Edit conflict detected between '$($Existing.Reason)' at offsets [$($Existing.StartOffset), $($Existing.EndOffset)) and '$($Edit.Reason)' at offsets [$($Edit.StartOffset), $($Edit.EndOffset))."
                $Exception = [InvalidOperationException]::new($Message)
                $Exception.Data['ExistingEdit'] = @{
                    StartOffset = $Existing.StartOffset
                    EndOffset = $Existing.EndOffset
                    ReplacementText = $Existing.ReplacementText
                    Reason = $Existing.Reason
                }
                $Exception.Data['IncomingEdit'] = @{
                    StartOffset = $Edit.StartOffset
                    EndOffset = $Edit.EndOffset
                    ReplacementText = $Edit.ReplacementText
                    Reason = $Edit.Reason
                }
                throw $Exception
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

    [void] ReplaceRange(
        [int] $StartOffset,
        [int] $EndOffset,
        [string] $NewText,
        [string] $Reason
    ) {
        if ($EndOffset -gt $this.OriginalText.Length) {
            throw "EndOffset $EndOffset exceeds document length $($this.OriginalText.Length)."
        }

        $Edit = [AstTextEdit]::new(
            $StartOffset,
            $EndOffset,
            $NewText,
            $Reason
        )
        $this.AddEdit($Edit)
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


$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$Paths = @(
    'Private'
    'Public'
)

foreach ($Path in $Paths) {
    Get-ChildItem -Path "$ModuleRoot/$Path" -Recurse -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}

# MARK: EXPORTS
#
# Prevent `Should-Process` from triggering invalid verb warning because
# `Import-Module` uses everything by default if `Export-ModuleMember` is
# not specified even if the manifest gets applied afterwards. Don't feel
# like aliasing `Should-Process` to avoid the invalid verb warning.
#
# Powershell module loading is so unnecessarily bad...
$ManifestPath = Join-Path -Path $ModuleRoot -ChildPath 'AstEditor.psd1'
if (-not (Test-Path -Path $ManifestPath)) {
    throw "Module manifest not found at '$ManifestPath'."
}

try {
    $Manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath -ErrorAction Stop
} catch {
    throw "Failed to load module manifest '$ManifestPath'. Error: $_"
}

$ExportParams = @{}
if ($Manifest.FunctionsToExport.Count -gt 0) {
    $ExportParams.Function = $Manifest.FunctionsToExport
}
if ($Manifest.CmdletsToExport.Count -gt 0) {
    $ExportParams.Cmdlet = $Manifest.CmdletsToExport
}
if ($Manifest.VariablesToExport.Count -gt 0) {
    $ExportParams.Variable = $Manifest.VariablesToExport
}
if ($Manifest.AliasesToExport.Count -gt 0) {
    $ExportParams.Alias = $Manifest.AliasesToExport
}

Export-ModuleMember @ExportParams






















