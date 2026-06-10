<#
.SYNOPSIS
    Generates a map of property setting functions that prevent the need to call `Brush`.

.DESCRIPTION
    This function analyzes a provided scriptblock to identify potential implicit brush commands.
    It generates a mapping of these command names to scriptblocks that can be invoked to apply
    the corresponding brush setters to WPF styles. The function takes into account reserved
    command names and allows for customization of the context name used in error messages.

.EXAMPLE
    Define implicit brush setters for a style.

    $styleScript = {
        Background: 'MyBackgroundResource'
        BorderBrush: 'MyBorderBrushResource'
    }

    $brushFunctionMap = New-WPFImplicitBrushFunctionMap `
        -ScriptBlock $styleScript `
        -ContextName 'Style'
#>
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
