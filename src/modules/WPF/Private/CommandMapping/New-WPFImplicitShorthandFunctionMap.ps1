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
