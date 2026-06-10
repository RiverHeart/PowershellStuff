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
