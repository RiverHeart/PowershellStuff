<#
.SYNOPSIS
    Keyword for defining a column specification in a WPF Grid.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Column Expand { ...code... }
#>
function Column {
    [CmdletBinding(DefaultParameterSetName = 'Width')]
    [Alias('-Column')]
    [OutputType([pscustomobject])]
    param(
        # Keep this as string so callers can use intuitive tokens like Fit and Expand.
        [Parameter(ParameterSetName = 'Width', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
        [ValidateNotNullOrEmpty()]
        [string] $Width = [System.Windows.GridLength]::Auto,

        [Parameter(Mandatory, ParameterSetName = 'Width', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [ScriptBlock] $ScriptBlock
    )

    if ($Width -is [ScriptBlock] -and -not $PSBoundParameters.ContainsKey('ScriptBlock')) {
        $ScriptBlock = $Width
        $Width = [System.Windows.GridLength]::Auto
    }

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation
        return
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent -and $Parent -isnot [System.Windows.Controls.Grid]) {
        throw "Cannot add column to $($Parent.Name) ($($Parent.GetType().Name))"
    }

    # Support intuitive names
    if ($Width -ilike 'Expand*') {
        # Convert (Expand -> * && 'Expand*2' -> 2*)
        $Width = $Width -replace 'Expand[*]?(\d)?', '$1*'
    } elseif ($Width -eq 'Fit') {
        $Width = $Width -replace 'Fit', 'Auto'
    }

    $PSVars = New-WPFVariableList -InputObject $Parent
    $Children = @($ScriptBlock.InvokeWithContext($null, $PSVars))

    if ($Children.Count -gt 1 -and -not $Parent.AllowPackedCells) {
        throw "This grid isn't configured to allow multiple children per cell. Use a StackPanel or other container to group multiple children into a single child. To opt out of this behavior, set `AllowPackedCells = `$true` on the grid."
    }

    return [pscustomobject] @{
        PSTypeName = 'WPF.Grid.ColumnSpec'
        Width = [System.Windows.GridLength] $Width
        Children = $Children
    }
}
