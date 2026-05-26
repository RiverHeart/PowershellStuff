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

    $styleDslCommands = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($dslCommandName in @('Setter', 'Trigger', 'DataTrigger', 'MultiTrigger', 'Chrome', 'ExtendStyle', 'Template')) {
        $null = $styleDslCommands.Add($dslCommandName)
    }

    $implicitSetterCommandMap = [Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)

    $isStyleDependencyProperty = {
        param(
            [Parameter(Mandatory)]
            [string] $PropertyName
        )

        $descriptor = [DependencyPropertyDescriptor]::FromName($PropertyName, $resolvedType, $resolvedType)
        return ($null -ne $descriptor)
    }

    # MARK: PROCESS

    # Phase 1: inspect command AST nodes and decide which names should behave like
    # implicit Setters in this style scope.
    $commandAsts = $ScriptBlock.Ast.FindAll({
            param($Ast)
            $Ast -is [CommandAst]
        }, $true)

    foreach ($commandAst in $commandAsts) {
        $commandName = $commandAst.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($commandName)) {
            continue
        }

        $isExplicitProperty = $commandName.EndsWith(':')
        $propertyName = if ($isExplicitProperty) {
            $commandName.Substring(0, $commandName.Length - 1)
        } else {
            $commandName
        }

        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            continue
        }

        $treatAsImplicitSetter = $false

        # Apply property resolution rules.
        if ($isExplicitProperty) {
            $treatAsImplicitSetter = $true
        } elseif ($styleDslCommands.Contains($propertyName)) {
            # Reserved style keywords are explicit unless caller opts into
            # property mode via the trailing ':' delimiter.
            $treatAsImplicitSetter = $false
        } elseif (& $isStyleDependencyProperty -PropertyName $propertyName) {
            # Prefer dependency properties over command names to reduce DSL collisions.
            $treatAsImplicitSetter = $true
        } elseif ($null -ne (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            $treatAsImplicitSetter = $false
        } else {
            $treatAsImplicitSetter = $true
        }

        if ($treatAsImplicitSetter -and -not $implicitSetterCommandMap.ContainsKey($commandName)) {
            $implicitSetterCommandMap[$commandName] = $propertyName
        }
    }

    # Phase 2: create transient helper functions for each implicit command.
    # These run in the caller's style scriptblock and delegate to Setter.
    $implicitSetterFunctions = [Dictionary[string, scriptblock]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($commandName in $implicitSetterCommandMap.Keys) {
        $propertyName = $implicitSetterCommandMap[$commandName]
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
    throw "Style shorthand for property '$propertyName' received unsupported trailing arguments: `$(`$Remaining -join ', ')"
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
    $implicitSetterFunctions[$commandName] = $functionBody
    }

    # Phase 3: Execute once with injected helpers and WPF DSL variables. This keeps normal
    # scriptblock behavior intact while enabling shorthand property commands.
    $null = $ScriptBlock.InvokeWithContext($implicitSetterFunctions, $PSVars, @())

    if ($isNamedStyle) {
        $script:WPFStyleTable[$Name] = $style
    } else {
        $script:WPFImplicitStyleTable[$resolvedType.FullName] = $style
    }
}
