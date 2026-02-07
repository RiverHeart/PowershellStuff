<#
.SYNOPSIS
    Keyword for defining an array of objects in a WPF GridColumn.
#>
function Column {
    [CmdletBinding(DefaultParameterSetName='Implicit')]
    [OutputType([object[]])]
    param(
        # Using object because you're probably going to pass a string
        # or int instead of [GridLength] and we need Powershell to recognize
        # the value to resolve the parameter set.
        [Parameter(ParameterSetName='Explicit',Position=0)]
        [object] $Width = [System.Windows.GridLength]::Auto,

        [Parameter(Mandatory,ParameterSetName='Explicit',Position=1)]
        [Parameter(Mandatory,ParameterSetName='Implicit',Position=0)]
        [ScriptBlock] $ScriptBlock
    )

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

    $PSVars = @(
        [psvariable]::new('this', $Parent)
    )

    # Ensure that single the array isn't unrolled
    return , @($ScriptBlock.InvokeWithContext($null, $PSVars))
}
