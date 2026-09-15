function New-WPFLinkValueConverter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool] $HasMap,

        [Parameter(Mandatory)]
        [bool] $HasTransform,

        [Parameter(Mandatory)]
        [bool] $HasDefault,

        [Parameter(Mandatory)]
        [bool] $UseStrictMap,

        [Parameter(Mandatory)]
        [bool] $UseInvert,

        [AllowNull()]
        [hashtable] $Map,

        [AllowNull()]
        [object] $Default,

        [AllowNull()]
        [scriptblock] $Transform
    )

    if ($HasMap) {
        $ScriptBlockMapKeys = @()
        foreach ($MapKey in $Map.Keys) {
            if ($Map[$MapKey] -is [scriptblock]) {
                $ScriptBlockMapKeys += [string] $MapKey
            }
        }

        if ($ScriptBlockMapKeys.Count -gt 0) {
            $ScriptBlockMapKeyList = $ScriptBlockMapKeys -join ', '
            Write-Warning "Link: -Map contains scriptblock value(s) for key(s): $ScriptBlockMapKeyList. Use evaluated values/objects in -Map (for example, wrap Path calls in parentheses)."
        }
    }

    return {
        param($Value)

        $FinalValue = if ($UseInvert) { -not $Value } else { $Value }

        if ($HasMap) {
            if ($Map.Contains($FinalValue)) {
                return $Map[$FinalValue]
            }

            if ($FinalValue -is [bool]) {
                $BoolKeyText = if ($FinalValue) { 'True' } else { 'False' }
                if ($Map.Contains($BoolKeyText)) {
                    return $Map[$BoolKeyText]
                }
            }

            if ($HasDefault) {
                return $Default
            }

            if ($UseStrictMap) {
                throw "Link: -Map has no entry for source value '$FinalValue'."
            }

            return $FinalValue
        }

        if ($HasTransform) {
            $HasParams = $Transform.Ast.ParamBlock -and $Transform.Ast.ParamBlock.Parameters.Count -gt 0
            if ($HasParams) {
                return (& $Transform $FinalValue)
            }

            $PSVars = [System.Collections.Generic.List[psvariable]]::new()
            $PSVars.Add([psvariable]::new('_', $FinalValue))
            $PSVars.Add([psvariable]::new('PSItem', $FinalValue))
            $Results = $Transform.InvokeWithContext($null, $PSVars)
            if ($Results.Count -gt 0) {
                return $Results[0]
            }
        }

        return $FinalValue
    }.GetNewClosure()
}
