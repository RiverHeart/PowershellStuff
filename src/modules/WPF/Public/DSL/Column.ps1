<#
.SYNOPSIS
    Keyword for defining a column specification in a WPF Grid.
#>
function Column {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Keep this as object so callers can use intuitive tokens like Fit and Expand.
        [Parameter(Position=0)]
        [object] $Width = [System.Windows.GridLength]::Auto,

        [Parameter(Position=1)]
        [ScriptBlock] $ScriptBlock
    )

    if ($Width -is [ScriptBlock] -and -not $PSBoundParameters.ContainsKey('ScriptBlock')) {
        $ScriptBlock = $Width
        $Width = [System.Windows.GridLength]::Auto
    }

    if (-not $ScriptBlock) {
        throw 'Column requires a scriptblock.'
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent -and $Parent -isnot [System.Windows.Controls.Grid]) {
        throw "Cannot add column to $($Parent.Name) ($($Parent.GetType().Name)"
    }

    # Support intuitive names
    if ($Width -ilike 'Expand*') {
        # Convert (Expand -> * && 'Expand*2' -> 2*)
        $Width = $Width -replace 'Expand[*]?(\d)?', '$1*'
    } elseif ($Width -eq 'Fit') {
        $Width = $Width -replace 'Fit', 'Auto'
    }

    $PSVars = @([psvariable]::new('this', $Parent))
    $Children = @($ScriptBlock.InvokeWithContext($null, $PSVars))

    return [pscustomobject] @{
        PSTypeName = 'WPF.Grid.ColumnSpec'
        Width = [System.Windows.GridLength] $Width
        Children = $Children
    }
}
