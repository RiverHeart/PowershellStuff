using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Creates a detached edit that removes an element from a delimited AST collection.

.DESCRIPTION
    Locates the delimiter following the selected element, or the preceding delimiter when
    the element is last, and returns an extent-backed edit. Trivia between the element and
    delimiter is retained as replacement text. The returned edit contains all source
    coordinates needed by an editor or correction engine.

.PARAMETER Remove
    The AST element to remove.

.PARAMETER From
    The ordered AST collection containing the element.

.PARAMETER Within
    The parent AST node whose source contains the collection and its delimiters.

.PARAMETER Delimiter
    The token kind separating collection elements. The default is Comma.

.PARAMETER Reason
    A description identifying the structural edit in previews and diagnostics.

.EXAMPLE
    $Document = New-AstDocument -InputObject @'
    param([Parameter(Position=0,Mandatory=$false)] [string] $Name)
    '@
    $Attribute = $Document.Ast.Find({
        param ($Node)

        $Node -is [System.Management.Automation.Language.AttributeAst] -and
            $Node.TypeName.Name -eq 'Parameter'
    }, $false)
    $Argument = $Attribute.NamedArguments |
        Where-Object ArgumentName -eq 'Mandatory'

    $Edit = New-AstCollectionEdit `
        -Remove $Argument `
        -From $Attribute.NamedArguments `
        -Within $Attribute

    Creates a detached edit that removes the Mandatory argument and its adjacent comma.
#>
function New-AstCollectionEdit {
    [CmdletBinding()]
    [OutputType('AstTextEdit')]
    param (
        [Parameter(Mandatory)]
        [Ast] $Remove,

        [Parameter(Mandatory)]
        [Ast[]] $From,

        [Parameter(Mandatory)]
        [Ast] $Within,

        [TokenKind] $Delimiter = [TokenKind]::Comma,

        [ValidateNotNullOrEmpty()]
        [string] $Reason = 'Remove an element from a delimited collection'
    )

    $ElementIndex = [array]::IndexOf($From, $Remove)
    if ($ElementIndex -lt 0) {
        throw 'The element to remove does not belong to the supplied collection.'
    }
    if ($Remove.Extent.StartOffset -lt $Within.Extent.StartOffset -or
        $Remove.Extent.EndOffset -gt $Within.Extent.EndOffset
    ) {
        throw 'The element to remove is outside the supplied parent AST node.'
    }

    $PreviousElement = if ($ElementIndex -gt 0) { $From[$ElementIndex - 1] }
    $NextElement = $From[$ElementIndex + 1]
    $SourceText = $Within.Extent.StartScriptPosition.GetFullScript()
    $Tokens = $null
    $ParseErrors = $null
    [void] [Parser]::ParseInput($SourceText, [ref] $Tokens, [ref] $ParseErrors)
    $DelimiterTokens = @($Tokens | Where-Object Kind -eq $Delimiter)

    $DelimiterToken = if ($NextElement) {
        $DelimiterTokens | Where-Object {
            $_.Extent.StartOffset -ge $Remove.Extent.EndOffset -and
                $_.Extent.StartOffset -lt $NextElement.Extent.StartOffset
        } | Select-Object -First 1
    } elseif ($PreviousElement) {
        $DelimiterTokens | Where-Object {
            $_.Extent.StartOffset -ge $PreviousElement.Extent.EndOffset -and
                $_.Extent.StartOffset -lt $Remove.Extent.StartOffset
        } | Select-Object -Last 1
    }

    if (-not $DelimiterToken) {
        if ($PreviousElement -or $NextElement) {
            throw "Could not find a $Delimiter token adjacent to the selected element."
        }

        $StartPosition = $Remove.Extent.StartScriptPosition
        $EndPosition = $Remove.Extent.EndScriptPosition
        $ReplacementText = ''
    } elseif ($NextElement) {
        $StartPosition = $Remove.Extent.StartScriptPosition
        $EndPosition = $DelimiterToken.Extent.EndScriptPosition
        $ReplacementText = $SourceText.Substring(
            $Remove.Extent.EndOffset,
            $DelimiterToken.Extent.StartOffset - $Remove.Extent.EndOffset
        )
    } else {
        $StartPosition = $DelimiterToken.Extent.StartScriptPosition
        $EndPosition = $Remove.Extent.EndScriptPosition
        $ReplacementText = $SourceText.Substring(
            $DelimiterToken.Extent.EndOffset,
            $Remove.Extent.StartOffset - $DelimiterToken.Extent.EndOffset
        )
    }

    $StartOffset = $StartPosition.Offset
    $EndOffset = $EndPosition.Offset

    return [AstTextEdit]::new(@{
        StartLineNumber = $StartPosition.LineNumber
        EndLineNumber = $EndPosition.LineNumber
        StartColumnNumber = $StartPosition.ColumnNumber
        EndColumnNumber = $EndPosition.ColumnNumber
        StartOffset = $StartOffset
        EndOffset = $EndOffset
        ExpectedText = $SourceText.Substring($StartOffset, $EndOffset - $StartOffset)
        ReplacementText = $ReplacementText
        Reason = $Reason
    })
}
