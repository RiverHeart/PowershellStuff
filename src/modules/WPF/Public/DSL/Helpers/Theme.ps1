<#
.SYNOPSIS
    Defines a named theme resource dictionary.

.DESCRIPTION
    Creates a ResourceDictionary and stores it in module state under the
    provided theme name. Use Brush inside the script block to populate values.

.EXAMPLE
    Theme 'Dark' {
        Brush 'WindowBackground' '#1E1E1E'
    }
#>
function Theme {
    [CmdletBinding()]
    [OutputType([System.Windows.ResourceDictionary])]
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
    $PSVars = @(
        [psvariable]::new('this', $dictionary)
    )

    $null = $ScriptBlock.InvokeWithContext($null, $PSVars)
    $dictionary['__WPFThemeName'] = $Name
    $script:WPFThemeTable[$Name] = $dictionary

    return $dictionary
}
