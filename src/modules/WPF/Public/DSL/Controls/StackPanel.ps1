<#
.SYNOPSIS
    Creates a WPF StackPanel object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -StackPanel 'MyPanel' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.stackpanel
#>
function StackPanel {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-StackPanel', 'VStackPanel', 'HStackPanel')]
    [OutputType([void], [System.Windows.Controls.StackPanel])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ -not ($_ -is [scriptblock]) })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [ScriptBlock] $ScriptBlock
    )

    # Change behavior based on invocation name.
    switch ($MyInvocation.InvocationName) {
        { $_.StartsWith('-') } {
            Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
            return
        }
        'VStackPanel' { $Orientation = [System.Windows.Controls.Orientation]::Vertical; break }
        'HStackPanel' { $Orientation = [System.Windows.Controls.Orientation]::Horizontal; break }
        default { $Orientation = [System.Windows.Controls.Orientation]::Vertical }
    }

    try {
        $StackPanel = [System.Windows.Controls.StackPanel] @{
            Orientation = $Orientation
        }
        if ($Name -ne '__Nameless__') {
            $StackPanel.Name = $Name
            Register-WPFObject $Name $StackPanel
        }
        Add-WPFType $StackPanel 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (StackPanel) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $StackPanel.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (StackPanel)"
        Update-WPFObject $Parent $StackPanel
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (StackPanel)"
    Update-WPFObject $StackPanel $ScriptBlock

    $IsParentedAfter = [bool] $StackPanel.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $StackPanel
    }
}
