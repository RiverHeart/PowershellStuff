<#
.SYNOPSIS
    Defines a named theme resource dictionary.

.DESCRIPTION
    Creates a ResourceDictionary and stores it in module state under the
    provided theme name. Use Brush inside the script block to populate values.

    To support implicit theme syntax (for example: WindowBackground: '#FFFFFF'),
    Theme performs a lightweight AST pass to identify candidate command names,
    then injects temporary helper functions into the scriptblock execution
    scope. Each helper forwards to Brush with the resolved resource key.

    This preserves normal scriptblock execution semantics (variables,
    expressions, and control flow) while allowing key-like shorthand.

.EXAMPLE
    Theme 'Dark' {
        WindowBackground: '#1E1E1E'
    }
#>
function Theme {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock] $ScriptBlock
    )

    if (-not $script:WPFThemeTable) {
        $script:WPFThemeTable = @{}
    }

    $dictionary = [System.Windows.ResourceDictionary]::new()
    $PSVars = New-WPFVariableList -InputObject $dictionary

    $themeDslCommands = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($dslCommandName in @('Brush')) {
        $null = $themeDslCommands.Add($dslCommandName)
    }

    $implicitBrushCommandMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Phase 1: inspect command AST nodes and decide which names should behave like
    # implicit Brush calls in this theme scope.
    $commandAsts = $ScriptBlock.Ast.FindAll({
            param($Ast)
            $Ast -is [System.Management.Automation.Language.CommandAst]
        }, $true)

    foreach ($commandAst in $commandAsts) {
        $commandName = $commandAst.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($commandName)) {
            continue
        }

        $isExplicitKey = $commandName.EndsWith(':')
        $resourceKey = if ($isExplicitKey) {
            $commandName.Substring(0, $commandName.Length - 1)
        } else {
            $commandName
        }

        if ([string]::IsNullOrWhiteSpace($resourceKey)) {
            continue
        }

        $treatAsImplicitBrush = $false

        if ($isExplicitKey) {
            $treatAsImplicitBrush = $true
        } elseif ($themeDslCommands.Contains($resourceKey)) {
            # Reserved Theme keywords remain explicit unless caller opts into
            # key mode with the trailing ':' delimiter.
            $treatAsImplicitBrush = $false
        } elseif ($null -ne (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            $treatAsImplicitBrush = $false
        } else {
            $treatAsImplicitBrush = $true
        }

        if ($treatAsImplicitBrush -and -not $implicitBrushCommandMap.ContainsKey($commandName)) {
            $implicitBrushCommandMap[$commandName] = $resourceKey
        }
    }

    # Phase 2: create transient helper functions for each implicit command.
    # These run in the caller's theme scriptblock and delegate to Brush.
    $implicitBrushFunctions = [System.Collections.Generic.Dictionary[string, scriptblock]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($themeCommandName in $implicitBrushCommandMap.Keys) {
        $resourceKey = $implicitBrushCommandMap[$themeCommandName]
        $functionBody = [scriptblock]::Create(@"
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]`$Color,

    [Parameter(ValueFromRemainingArguments = `$true)]
    [object[]]`$Remaining
)

if (`$null -ne `$Remaining -and `$Remaining.Count -gt 0) {
    throw "Theme shorthand for key '$resourceKey' received unsupported trailing arguments: `$(`$Remaining -join ', ')"
}

Brush '$resourceKey' `$Color
"@)
    $implicitBrushFunctions[$themeCommandName] = $functionBody
    }

    # Execute once with injected helpers and WPF DSL variables. This keeps normal
    # scriptblock behavior intact while enabling shorthand theme keys.
    $null = $ScriptBlock.InvokeWithContext($implicitBrushFunctions, $PSVars, @())
    $dictionary['__WPFThemeName'] = $Name
    $script:WPFThemeTable[$Name] = $dictionary
}
