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
        [ValidateScript({ Test-AstDocumentInstance -InputObject $_ })]
        [object] $Document,

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
