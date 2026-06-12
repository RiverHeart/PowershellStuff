<#
.SYNOPSIS
    Generates colon-shorthand setter functions for Style script blocks.

.DESCRIPTION
    This function is a function factory for style shorthand syntax.

    It analyzes a style script block and builds a dictionary where each key is a shorthand
    command name (typically a colon form such as 'Background:') and each value is a
    scriptblock that forwards to Setter with the resolved property name.

    Shorthand is a syntax form only. Explicit setter calls (for example, Setter Foo Bar)
    remain supported and are not replaced by this map.

    The generated scriptblocks are invoked in the caller's execution scope, which preserves
    style script context without requiring recreation of user-authored script blocks.

.EXAMPLE
    Use colon syntax to define style setters.

    $styleScript = {
        FontSize: 16
        Margin: '2,4,6,8'
        FocusVisualStyle: $null
    }

    $setterMap = New-WPFStylePropertyHandler `
        -ScriptBlock $styleScript
#>
function New-WPFStylePropertyHandler {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[string, scriptblock]])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ContextName = 'Style'
    )

    $PropertyDeclarationMap = Get-WPFPropertyDeclaration -ScriptBlock $ScriptBlock

    $PropertyDeclarationFuncs = [System.Collections.Generic.Dictionary[string, scriptblock]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($propertyDeclaration in $PropertyDeclarationMap.Keys) {
        $propertyName = $PropertyDeclarationMap[$propertyDeclaration]
        $functionBody = [scriptblock]::Create(@"
param(
    [Parameter(Mandatory, Position = 0)]
    [AllowNull()]
    [object]`$Value,

    [Parameter()]
    [switch]`$Resource,

    [Parameter()]
    [string]`$Target,

    [Parameter()]
    [ValidateSet('Chrome')]
    [string]`$Scope,

    [Parameter(ValueFromRemainingArguments = `$true)]
    [object[]]`$Remaining
)

if (`$null -ne `$Remaining -and `$Remaining.Count -gt 0) {
    throw "$ContextName shorthand for property '$propertyName' received unsupported trailing arguments: `$(`$Remaining -join ', ')"
}

`$setterArgs = @{
    Property = '$propertyName'
    Value = `$Value
}

if (`$PSBoundParameters.ContainsKey('Resource')) {
    `$setterArgs['Resource'] = `$Resource
}

if (`$PSBoundParameters.ContainsKey('Target')) {
    `$setterArgs['Target'] = `$Target
}

if (`$PSBoundParameters.ContainsKey('Scope')) {
    `$setterArgs['Scope'] = `$Scope
}

Setter @setterArgs
"@)

        $PropertyDeclarationFuncs[$propertyDeclaration] = $functionBody
    }

    return $PropertyDeclarationFuncs
}
