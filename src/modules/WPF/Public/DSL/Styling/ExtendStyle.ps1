<#
.SYNOPSIS
    Sets the current style's base style.

.DESCRIPTION
    Applies WPF style inheritance by assigning the current Style.BasedOn.

    Supported inputs:
    - Named style key (string): ExtendStyle 'PrimaryButtonBase'
    - Target type (type or DSL short name): ExtendStyle Button
      This resolves to the implicit style for that target type.
    - Style instance: ExtendStyle $SomeStyle

.EXAMPLE
    Style Button {
        Setter Margin '0,8,0,0'
    }

    Style 'PrimaryButton' Button {
        ExtendStyle Button
        Setter Background '#0A84FF'
    }
#>
function ExtendStyle {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [object] $Base
    )

    $style = $PSCmdlet.GetVariableValue('this')
    if (-not ($style -is [System.Windows.Style])) {
        Write-Error 'ExtendStyle: Must be used directly inside a Style block.'
        return
    }

    if ($null -ne $style.BasedOn) {
        Write-Error 'ExtendStyle: BasedOn is already set for this style.'
        return
    }

    if (-not $script:WPFStyleTable) {
        $script:WPFStyleTable = @{}
    }

    if (-not $script:WPFImplicitStyleTable) {
        $script:WPFImplicitStyleTable = @{}
    }

    $baseStyle = $null

    if ($Base -is [System.Windows.Style]) {
        $baseStyle = $Base
    }
    elseif ($Base -is [string] -and $script:WPFStyleTable.ContainsKey($Base)) {
        $baseStyle = $script:WPFStyleTable[$Base]
    }
    else {
        $resolvedType = if ($Base -is [type]) {
            $Base
        }
        else {
            $typeInfo = @(Get-WPFTypeInfo -Name $Base)
            if ($typeInfo.Count -eq 1) {
                $typeInfo[0]
            }
            else {
                $null
            }
        }

        if ($null -ne $resolvedType) {
            $implicitKey = $resolvedType.FullName
            if ($script:WPFImplicitStyleTable.ContainsKey($implicitKey)) {
                $baseStyle = $script:WPFImplicitStyleTable[$implicitKey]
            }
            else {
                Write-Error "ExtendStyle: No implicit style is registered for target type '$($resolvedType.FullName)'."
                return
            }
        }
        else {
            Write-Error "ExtendStyle: Could not resolve base style from '$Base'."
            return
        }
    }

    if ($null -eq $baseStyle.TargetType) {
        Write-Error 'ExtendStyle: Base style target type is not set.'
        return
    }

    if ($null -eq $style.TargetType) {
        Write-Error 'ExtendStyle: Current style target type is not set.'
        return
    }

    if (-not $baseStyle.TargetType.IsAssignableFrom($style.TargetType)) {
        Write-Error "ExtendStyle: Base target type '$($baseStyle.TargetType.FullName)' is not compatible with '$($style.TargetType.FullName)'."
        return
    }

    $style.BasedOn = $baseStyle
}
