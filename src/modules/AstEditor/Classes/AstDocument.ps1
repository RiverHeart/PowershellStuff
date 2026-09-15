using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation.Language

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

    [void] ReplaceRange(
        [int] $StartOffset,
        [int] $EndOffset,
        [string] $NewText,
        [string] $Reason
    ) {
        if ($EndOffset -gt $this.OriginalText.Length) {
            throw "EndOffset $EndOffset exceeds document length $($this.OriginalText.Length)."
        }

        $this.AddEdit([AstTextEdit]::new(
            $StartOffset,
            $EndOffset,
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
