<#
.SYNOPSIS
    Generates colon-shorthand brush functions for Theme script blocks.

.DESCRIPTION
    This function is a function factory for theme shorthand syntax.

    It analyzes a theme script block and builds a dictionary where each key is a shorthand
    command name (typically a colon form such as 'WindowBackground:') and each value is a
    scriptblock that forwards to Brush with the resolved key.

    Shorthand is a syntax form only. Explicit brush calls (for example, Brush Foo '#112233')
    remain supported and are not replaced by this map.

    The generated scriptblocks are invoked in the caller's execution scope, which preserves
    theme script context without requiring recreation of user-authored script blocks.

.EXAMPLE
    Define colon shorthand brush entries for a theme.

    $themeScript = {
        Background: 'MyBackgroundResource'
        BorderBrush: 'MyBorderBrushResource'
    }

    $brushFunctionMap = New-WPFThemePropertyHandler `
        -ScriptBlock $themeScript `
        -ContextName 'Theme'
#>
function New-WPFThemePropertyHandler {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[string, scriptblock]])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ContextName = 'Theme'
    )

    $propertyDeclarationMap = Get-WPFPropertyDeclaration -ScriptBlock $ScriptBlock

    $propertyDeclarationFuncs = [System.Collections.Generic.Dictionary[string, scriptblock]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($propertyDeclaration in $propertyDeclarationMap.Keys) {
        $resourceKey = $propertyDeclarationMap[$propertyDeclaration]
        $functionBody = [scriptblock]::Create(@"
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]`$Color,

    [Parameter(ValueFromRemainingArguments = `$true)]
    [object[]]`$Remaining
)

if (`$null -ne `$Remaining -and `$Remaining.Count -gt 0) {
    throw "$ContextName shorthand for key '$resourceKey' received unsupported trailing arguments: `$(`$Remaining -join ', ')"
}

Brush '$resourceKey' `$Color
"@)

        $propertyDeclarationFuncs[$propertyDeclaration] = $functionBody
    }

    return $propertyDeclarationFuncs
}
