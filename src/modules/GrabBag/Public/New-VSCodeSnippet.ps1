<#
.SYNOPSIS
    Creates a VSCode snippet from a given string or scriptblock

.EXAMPLE
    $Snippet = New-VSCodeSnippet `
        -Name "Print to console" `
        -Description "Log output to console" `
        -Prefix "log" `
        -IsFileTemplate `
        -Body {
Write-Host '$1'
'$2'
$foo = 'foo'
Write-Host $foo
}
    $Snippet                  # Display snippet
    $Snippet | Set-Clipboard  # Copy snippet to paste
#>
function New-VSCodeSnippet {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Description,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Prefix,

        [Parameter(Mandatory,HelpMessage="Script body. Should normally be a string or scriptblock but can be anything that converts to a string object.")]
        [ValidateNotNullOrEmpty()]
        [Object] $Body,

        [Parameter(HelpMessage="File which this snippet is relevant to. (eg powershell)")]
        [ValidateNotNullOrEmpty()]
        $Scope,

        [switch] $IsFileTemplate
    )

    # Convert to string. Deindent automatically if command is available.
    $BodyString = $Body.ToString()
    if (Get-Command Dedent-String -ErrorAction Ignore) {
        $BodyString = $BodyString | Deindent-String
    }

    # VSCode snippets treats numeric ($1, $2, etc) special so escape words
    # starting with $ (variables) and an alphabetic char, followed by any
    # non-whitespace char.
    $BodyLines = [Regex]::Replace($Body.ToString(), '(\B[$][a-zA-Z]\w+)', '\$1').Trim() -split "`n"

    $Properties = @{
        description = $Description
        prefix = $prefix
        isFileTemplate = $IsFileTemplate.IsPresent
        body = $BodyLines
    }
    if ($Scope) { $Properties.scope = $Scope }

    # Need a wrapper around $Properties to use ConvertTo-Json
    $Snippet = ([PSCustomObject] @{ $Name = $Properties }) | ConvertTo-Json -Depth 10

    # Remove braces and empty lines
    return $Snippet.Trim('{}').Trim()
}
