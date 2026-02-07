<#
.SYNOPSIS
    Keyword for defining an array of objects in a WPF GridColumn.
#>
function Row {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        # Using object because you're probably going to pass a string
        # or int instead of [GridLength] and we need Powershell to recognize
        # the value to resolve the parameter set.
        [Parameter(ParameterSetName='Explicit',Position=0)]
        [object] $Height = [System.Windows.GridLength]::Auto,

        [Parameter(Mandatory,ParameterSetName='Explicit',Position=1)]
        [Parameter(Mandatory,ParameterSetName='Implicit',Position=0)]
        [ScriptBlock] $ScriptBlock
    )

    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent -and $Parent -isnot [System.Windows.Controls.Grid]) {
        throw "Cannot add column to $($Parent.Name) ($($Parent.GetType().Name)"
    }

    # Support intuitive names
    if ($Height -ilike 'Expand*') {
        # Convert (Expand -> * && 'Expand*2' -> 2*)
        $Height = $Height -replace 'Expand[*]?(\d)?', '$1*'
    } elseif ($Height -eq 'Fit') {
        $Height = $Height -replace 'Fit', 'Auto'
    }

    $PSVars = @(
        [psvariable]::new('this', $Parent)
    )

    # Ensure that single the array isn't unrolled
    return , @($ScriptBlock.InvokeWithContext($null, $PSVars))
}
