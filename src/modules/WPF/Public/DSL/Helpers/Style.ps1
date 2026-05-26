using namespace System
using namespace System.Collections.Generic
using namespace System.ComponentModel
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Defines a WPF style.

.DESCRIPTION
    Creates a System.Windows.Style for the given target type.

    Supports two forms:

    * Named Style: Style 'App.Button' Button { ... }
    * Typed Style: Style Button { ... }

    Named styles are applied using UseStyle. Typed styles are registered by
    target type and auto-applied during control creation.

    To support implicit style syntax (for example: Background: 'Red'), Style
    performs a lightweight AST pass first to identify candidate command names,
    then injects temporary helper functions into the scriptblock execution
    scope. Each helper forwards to Setter with the original arguments.

    This preserves normal scriptblock execution semantics (variables,
    expressions, and control flow) while allowing property-like shorthand.

.EXAMPLE
    Style 'App.Button' Button {
        Background: ButtonBackground -Resource
    }

.EXAMPLE
    Style Button {
        Background: ButtonBackground -Resource
    }
#>
function Style {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [object] $NameOrTargetType,

        [Parameter(Mandatory, Position = 1)]
        [object] $TargetTypeOrScriptBlock,

        [Parameter(Position = 2)]
        [scriptblock] $ScriptBlock
    )

    # MARK: SETUP

    $isNamedStyle = $true
    if (
        $TargetTypeOrScriptBlock -is [scriptblock] -and
        -not $PSBoundParameters.ContainsKey('ScriptBlock')
    ) {
        $isNamedStyle = $false
        $TargetType = $NameOrTargetType
        $ScriptBlock = $TargetTypeOrScriptBlock
    } else {
        if (-not $PSBoundParameters.ContainsKey('ScriptBlock')) {
            throw 'Style requires a scriptblock.'
        }

        $Name = [string] $NameOrTargetType
        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw 'Style name cannot be empty for named styles.'
        }

        $TargetType = $TargetTypeOrScriptBlock
    }

    if (-not $script:WPFStyleTable) {
        $script:WPFStyleTable = @{}
    }

    if (-not $script:WPFImplicitStyleTable) {
        $script:WPFImplicitStyleTable = @{}
    }

    $resolvedType = if ($TargetType -is [type]) {
        $TargetType
    } else {
        $typeInfo = @(Get-WPFTypeInfo -Name $TargetType)
        if ($typeInfo.Count -ne 1) {
            Write-Error "Style: Failed to resolve target type '$TargetType'."
            return
        }

        $typeInfo[0]
    }

    $style = [System.Windows.Style]::new($resolvedType)
    $PSVars = New-WPFVariableList -InputObject $style

    $implicitSetterFunctions = New-WPFImplicitSetterFunctionMap `
        -ScriptBlock $ScriptBlock `
        -TargetType $resolvedType `
        -ReservedCommands @('Setter', 'Trigger', 'DataTrigger', 'MultiTrigger', 'Chrome', 'ExtendStyle', 'Template') `
        -ContextName 'Style'

    # Execute once with injected helpers and WPF DSL variables. This keeps
    # normal scriptblock behavior intact while enabling shorthand commands.
    $null = $ScriptBlock.InvokeWithContext($implicitSetterFunctions, $PSVars, @())

    if ($isNamedStyle) {
        $script:WPFStyleTable[$Name] = $style
    } else {
        $script:WPFImplicitStyleTable[$resolvedType.FullName] = $style
    }
}
