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

    $implicitBrushFunctions = New-WPFThemePropertyHandler `
        -ScriptBlock $ScriptBlock `
        -ContextName 'Theme'

    # Execute once with injected helpers and WPF DSL variables. This keeps normal
    # scriptblock behavior intact while enabling shorthand theme keys.
    $null = $ScriptBlock.InvokeWithContext($implicitBrushFunctions, $PSVars, @())
    $dictionary['__WPFThemeName'] = $Name
    $script:WPFThemeTable[$Name] = $dictionary
}
