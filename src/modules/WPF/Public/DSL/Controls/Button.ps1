<#
.SYNOPSIS
    Creates a WPF Button object.

.EXAMPLE
    Creates a Button with a Click event handler.

    Button 'MyButton' {
        On Click { Write-Host 'Clicked!' }
    }

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Button 'MyButton' { ...code... }
#>
function Button {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-Button')]
    [OutputType([void], [System.Windows.Controls.Button])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ -not ($_ -is [scriptblock]) })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $Button = [System.Windows.Controls.Button] @{
            Name = $Name
        }
        if ($Name -ne '__Nameless__') { Register-WPFObject $Name $Button }
        Add-WPFType $Button 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Button) with error: $_"
    }

    # Auto-attach if parent exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $Button.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (Button)"
        Update-WPFObject $Parent $Button
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Button)"
    Update-WPFObject $Button $ScriptBlock

    $IsParentedAfter = [bool] $Button.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $Button
    }
}
