function Get-WPFImplicitCommandMap {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[string, string]])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [string[]] $ReservedCommands = @(),

        [Parameter()]
        [scriptblock] $IsPreferredImplicitName,

        [Parameter()]
        [switch] $PreferNameMatchBeforeCommandResolution
    )

    $reservedCommandSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($reservedCommand in $ReservedCommands) {
        if (-not [string]::IsNullOrWhiteSpace($reservedCommand)) {
            $null = $reservedCommandSet.Add($reservedCommand)
        }
    }

    $implicitCommandMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $commandAsts = Find-AstNode -ScriptBlock $ScriptBlock -Type CommandAst -All -Recurse

    foreach ($commandAst in $commandAsts) {
        $commandName = $commandAst.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($commandName)) {
            continue
        }

        $isExplicitName = $commandName.EndsWith(':')
        $resolvedName = if ($isExplicitName) {
            $commandName.Substring(0, $commandName.Length - 1)
        } else {
            $commandName
        }

        if ([string]::IsNullOrWhiteSpace($resolvedName)) {
            continue
        }

        $treatAsImplicit = $false

        if ($isExplicitName) {
            $treatAsImplicit = $true
        } elseif ($reservedCommandSet.Contains($resolvedName)) {
            $treatAsImplicit = $false
        } elseif (
            $PreferNameMatchBeforeCommandResolution -and
            $null -ne $IsPreferredImplicitName -and
            (& $IsPreferredImplicitName -PropertyName $resolvedName)
        ) {
            $treatAsImplicit = $true
        } elseif ($null -ne (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            $treatAsImplicit = $false
        } else {
            $treatAsImplicit = $true
        }

        if ($treatAsImplicit -and -not $implicitCommandMap.ContainsKey($commandName)) {
            $implicitCommandMap[$commandName] = $resolvedName
        }
    }

    return $implicitCommandMap
}

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

function New-WPFImplicitBrushFunctionMap {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[string, scriptblock]])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [string[]] $ReservedCommands = @('Brush'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ContextName = 'Theme'
    )

    $implicitCommandMap = Get-WPFImplicitCommandMap -ScriptBlock $ScriptBlock -ReservedCommands $ReservedCommands

    $implicitFunctions = [System.Collections.Generic.Dictionary[string, scriptblock]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($commandName in $implicitCommandMap.Keys) {
        $resourceKey = $implicitCommandMap[$commandName]
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

        $implicitFunctions[$commandName] = $functionBody
    }

    return $implicitFunctions
}
