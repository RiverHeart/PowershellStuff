<#
.SYNOPSIS
    Generates a mapping of implicit setter function names to scriptblocks
    that implement the setter logic for WPF styles.

.DESCRIPTION
    This function analyzes a provided scriptblock (which defines a style) to identify
    potential implicit property setter commands. It generates a mapping of these command
    names to scriptblocks that can be invoked to apply the corresponding property setters
    to WPF styles. The function takes into account reserved command names, allows for
    customization of the context name used in error messages, and can prioritize certain
    implicit names based on a provided scriptblock.

.EXAMPLE
    Use colon syntax to define implicit setters for properties.

    $styleScript = {
        FontSize: 16
        Margin: '2,4,6,8'
        FocusVisualStyle: $null
    }

    $setterMap = New-WPFImplicitSetterFunctionMap `
        -ScriptBlock $styleScript `
        -TargetType [System.Windows.Controls.Button]
#>
function New-WPFImplicitSetterFunctionMap {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[string, scriptblock]])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory)]
        [type] $TargetType,

        [Parameter()]
        [string[]] $ReservedCommands = @('Setter'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ContextName = 'Style'
    )

    $isDependencyProperty = {
        param(
            [Parameter(Mandatory)]
            [string] $PropertyName
        )

        $descriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($PropertyName, $TargetType, $TargetType)
        return ($null -ne $descriptor)
    }

    $implicitCommandMap = Get-WPFImplicitCommandMap `
        -ScriptBlock $ScriptBlock `
        -ReservedCommands $ReservedCommands `
        -IsPreferredImplicitName $isDependencyProperty `
        -PreferNameMatchBeforeCommandResolution

    $implicitFunctions = [System.Collections.Generic.Dictionary[string, scriptblock]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($commandName in $implicitCommandMap.Keys) {
        $propertyName = $implicitCommandMap[$commandName]
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

        $implicitFunctions[$commandName] = $functionBody
    }

    return $implicitFunctions
}
