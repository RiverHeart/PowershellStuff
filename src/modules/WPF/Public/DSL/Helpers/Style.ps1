<#
.SYNOPSIS
    Defines a WPF style.

.DESCRIPTION
    Creates a System.Windows.Style for the given target type.

    Supports two forms:

    * Named style: Style 'App.Button' Button { ... }
    * Implicit style: Style Button { ... }

    Named styles are applied using UseStyle. Implicit styles are registered by
    target type and auto-applied during control creation.

.EXAMPLE
    Style 'App.Button' Button {
        Setter Background ButtonBackground -Resource
    }

.EXAMPLE
    Style Button {
        Setter Background ButtonBackground -Resource
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
    $PSVars = @(
        [psvariable]::new('this', $style)
    )

    $null = $ScriptBlock.InvokeWithContext($null, $PSVars)

    if ($isNamedStyle) {
        $script:WPFStyleTable[$Name] = $style
    } else {
        $script:WPFImplicitStyleTable[$resolvedType.FullName] = $style
    }
}
