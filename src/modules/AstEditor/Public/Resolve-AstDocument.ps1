using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Renders queued edits and re-parses the result, returning diagnostics.

.DESCRIPTION
    Renders all queued edits from an AstDocument into script text and parses
    that text again with PowerShell's parser. Returns parse diagnostics and edit counts
    so callers can gate writes or transforms on parse validity.
    Fragment documents validate the complete rendered snapshot, including errors
    outside the fragment. A fragment that no longer matches its type, offsets, and
    nesting depth is reported as a FragmentNotFound validation diagnostic.
    With PassThruText, RenderedText is the complete snapshot and
    RenderedFragmentText is the submitted fragment's slice (the two are equal for
    non-fragments). Neither text is written by this command.

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
    $Root = [Parser]::ParseInput(
        $RenderedText, $Document.Ast.Extent.File, [ref] $Tokens, [ref] $Errors
    )
    $RenderedFragmentText = $RenderedText
    if ($Document.IsFragment) {
        $EndOffset = $Document.GetRenderedFragmentEndOffset()
        $RenderedFragmentText = $RenderedText.Substring(
            $Document.Ast.Extent.StartOffset, $EndOffset - $Document.Ast.Extent.StartOffset
        )

        if ($Errors.Count -eq 0) {
            try {
                $null = $Document.FindFragment($Root, $Document.Ast, $EndOffset)
            } catch [System.InvalidOperationException] {
                $Errors = @([ParseError]::new(
                    $Root.Extent, 'FragmentNotFound', $_.Exception.Message
                ))
            }
        }
    }

    $Result = [pscustomobject] @{
        ParseErrorCount = $Errors.Count
        ParseErrors = $Errors
        EditCount = $Document.Edits.Count
        Path = $Document.Path
    }

    if ($PassThruText) {
        $Result | Add-Member -NotePropertyName RenderedText -NotePropertyValue $RenderedText
        $Result | Add-Member -NotePropertyName RenderedFragmentText -NotePropertyValue $RenderedFragmentText
    }

    return $Result
}
