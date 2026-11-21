using namespace System.Text.RegularExpressions

<#
.SYNOPSIS
    Finds script extents in a PowerShell document that match a specified regex pattern.

.DESCRIPTION
    This cmdlet searches through the original text of a PowerShell document
    and returns script extents that match the specified regex pattern.

.NOTES
    For convenience, you probably want to use the regex switches instead
    of the RegexOptions parameter.

.EXAMPLE
    Search for all function definitions and return their script extents.

    $Document = New-AstDocument -InputObject {
        function foo {}
        function bar { Write-Host "bar"}
        function baz {
            Write-Host "baz"
        }
    }

    Find-AstScriptExtent `
        -Document $Document `
        -Pattern 'function\s+\w+\s*\{[^}]*\}' `
        -Multiline
#>
function Find-AstScriptExtent {
    [CmdletBinding()]
    [OutputType('AstScriptExtent')]
    param(
        [Parameter(Mandatory, HelpMessage = "Specifies the document to search.")]
        [AstDocument] $Document,

        [Parameter(Mandatory, HelpMessage = "Specifies the regex pattern to match.")]
        [ValidateNotNullOrEmpty()]
        [string] $Pattern,

        [Parameter(HelpMessage = "Specifies the timeout in seconds for the regex match to complete.")]
        [TimeSpan] $Timeout = [TimeSpan]::FromSeconds(30),

        [Parameter(HelpMessage = "Specifies the regex options for the match.")]
        [RegexOptions] $RegexOptions = [RegexOptions]::None,

        [switch] $Multiline,
        [switch] $CaseSensitive
    )

    if ($Multiline) {
        $RegexOptions = $RegexOptions -bor [RegexOptions]::Multiline
    }

    if (-not $CaseSensitive) {
        $RegexOptions = $RegexOptions -bor [RegexOptions]::IgnoreCase
    }

    $Text = $Document.OriginalText
    $BaseOffset = 0

    # Limit the search to the fragment text if the document is a fragment
    if ($Document.IsFragment) {
        $Text = $Document.Ast.Extent.Text
        $BaseOffset = $Document.Ast.Extent.StartOffset
    }

    foreach ($Match in [regex]::Matches(
        $Text,
        $Pattern,
        $RegexOptions,
        $Timeout
    )) {
        $StartOffset = $BaseOffset + $Match.Index
        $EndOffset = $StartOffset + $Match.Length

        New-AstScriptExtent `
            -Document $Document `
            -StartOffset $StartOffset `
            -EndOffset $EndOffset
    }
}
