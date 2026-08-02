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
