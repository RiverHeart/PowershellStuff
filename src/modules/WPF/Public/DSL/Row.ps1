<#
.SYNOPSIS
    Keyword for defining a row specification in a WPF Grid.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Row Expand { ...code... }
#>
function Row {
    [CmdletBinding()]
    [Alias('-Row')]
    [OutputType([pscustomobject])]
    param(
        # Keep this as object so callers can use intuitive tokens like Fit and Expand.
        [Parameter(Position=0)]
        [object] $Height = [System.Windows.GridLength]::Auto,

        [Parameter(Position=1)]
        [ScriptBlock] $ScriptBlock
    )

    if ($Height -is [ScriptBlock] -and -not $PSBoundParameters.ContainsKey('ScriptBlock')) {
        $ScriptBlock = $Height
        $Height = [System.Windows.GridLength]::Auto
    }

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation
        return
    }

    if (-not $ScriptBlock) {
        throw 'Row requires a scriptblock.'
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent -and $Parent -isnot [System.Windows.Controls.Grid]) {
        throw "Cannot add row to $($Parent.Name) ($($Parent.GetType().Name))"
    }

    # Support intuitive names
    if ($Height -ilike 'Expand*') {
        # Convert (Expand -> * && 'Expand*2' -> 2*)
        $Height = $Height -replace 'Expand[*]?(\d)?', '$1*'
    } elseif ($Height -eq 'Fit') {
        $Height = $Height -replace 'Fit', 'Auto'
    }

    $PSVars = @([psvariable]::new('this', $Parent))
    $Columns = @($ScriptBlock.InvokeWithContext($null, $PSVars))

    return [pscustomobject] @{
        PSTypeName = 'WPF.Grid.RowSpec'
        Height = [System.Windows.GridLength] $Height
        Columns = $Columns
    }
}
