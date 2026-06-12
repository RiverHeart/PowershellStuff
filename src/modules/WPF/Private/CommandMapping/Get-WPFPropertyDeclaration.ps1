<#
.SYNOPSIS
    Extracts property declaration command tokens from a script block.

.DESCRIPTION
    Scans command invocations in a script block and returns a map of property declaration
    command tokens to their resolved names.

    This is a simple extraction helper for style and theme DSL syntax processing.
    Property declarations use the Name: Value form. Bare command names are ignored.

    The map key is the command token as written (for example, 'Background:'),
    and the map value is the name without the colon (for example, 'Background').

.EXAMPLE
    Extract property declarations from a style block.

    $styleScript = {
        FontSize: 16
        Margin: '2,4,6,8'
        Background: ButtonBackground -Resource
    }

    $propertyDeclarations = Get-WPFPropertyDeclaration -ScriptBlock $styleScript
    # Returns: @{ 'FontSize:' = 'FontSize'; 'Margin:' = 'Margin'; 'Background:' = 'Background' }
#>
function Get-WPFPropertyDeclaration {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[string, string]])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    $propertyDeclarationMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $commandAsts = Find-AstNode `
        -ScriptBlock $ScriptBlock `
        -Type CommandAst `
        -All `
        -Recurse `
        -Query {
            param($AstNode)
            $CommandName = $AstNode.GetCommandName()
            return (
                $AstNode.CommandElements.Count -ge 1 -and
                $CommandName -ne $null -and
                $CommandName.Length -gt 1 -and
                $CommandName.EndsWith(':')
            )
        }

    foreach ($CommandAst in $CommandAsts) {
        $CommandToken = $CommandAst.GetCommandName()
        $ResolvedName = $CommandToken.TrimEnd(':')
        if (-not $PropertyDeclarationMap.ContainsKey($CommandToken)) {
            $PropertyDeclarationMap[$CommandToken] = $ResolvedName
        }
    }

    return $PropertyDeclarationMap
}
