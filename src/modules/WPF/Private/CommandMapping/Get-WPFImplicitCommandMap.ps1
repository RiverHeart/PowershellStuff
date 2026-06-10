<#
.SYNOPSIS
    Analyzes a script block to identify potential implicit command names and
    maps them to their resolved forms.

.DESCRIPTION
    This function processes a provided script block to find command invocations that
    could be interpreted as implicit property setters or resource references. It generates
    a mapping of these command names to their resolved property or resource names, taking
    into account reserved command names and allowing for customization of the criteria used to
    identify implicit names.

.EXAMPLE
    Analyze a style definition to identify implicit property setter commands.

    $styleScript = {
        FontSize: 16
        Margin: '2,4,6,8'
        FocusVisualStyle: $null
    }

    $implicitCommandMap = Get-WPFImplicitCommandMap `
        -ScriptBlock $styleScript `
        -ReservedCommands @('Setter')
#>
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
